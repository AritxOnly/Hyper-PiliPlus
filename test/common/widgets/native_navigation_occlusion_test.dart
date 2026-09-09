import 'package:PiliPlus/common/widgets/native_navigation_occlusion.dart';
import 'package:PiliPlus/common/widgets/image_viewer/hero_dialog_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.aritxonly.hyperpiliplus/miuix_navigation');
  final calls = <bool>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setOverlayOccluded') {
            calls.add(call.arguments as bool);
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('sheet and toast leases restore only after both leave', (
    tester,
  ) async {
    final observer = NativeNavigationPopupObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) =>
                    const SizedBox(height: 200, child: Text('sheet')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(calls, [true]);
    final releaseToast = NativeNavigationOcclusion.acquire();
    Navigator.of(tester.element(find.text('sheet'))).pop();
    await tester.pump();
    expect(calls, [true]);
    await tester.pumpAndSettle();
    expect(calls, [true]); // toast still owns foreground
    releaseToast();
    releaseToast(); // idempotent
    await tester.pump();
    expect(calls, [true, false]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('foreground widget releases its lease on disposal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: NativeNavigationForeground(child: Text('toast')),
      ),
    );
    expect(calls, [true]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(calls, [true, false]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('transparent image routes occlude native chrome', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                HeroDialogRoute<void>(
                  pageBuilder: (_, _, _) => const NativeNavigationForeground(
                    child: SizedBox.expand(),
                  ),
                ),
              ),
              child: const Text('open image'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open image'));
    await tester.pumpAndSettle();
    expect(calls, [true]);
    Navigator.of(tester.element(find.byType(NativeNavigationForeground))).pop();
    await tester.pumpAndSettle();
    expect(calls, [true, false]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('real SmartDialog toast restores native chrome after dismissal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: FlutterSmartDialog.init(
          toastBuilder: (msg) => NativeNavigationForeground(child: Text(msg)),
        ),
        home: const Scaffold(),
      ),
    );
    SmartDialog.showToast(
      'toast',
      displayTime: const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(calls, [true]);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(calls, [true, false]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
