import 'package:PiliPlus/utils/freeform_window_insets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewSize = Size(375, 600);

  test('keeps normal full-screen insets unchanged', () {
    const insets = EdgeInsets.fromLTRB(0, 24, 0, 22);

    expect(
      FreeformWindowInsets.normalize(
        insets: insets,
        viewSize: viewSize,
      ),
      insets,
    );
  });

  test('removes an impossible HyperOS freeform top inset', () {
    const insets = EdgeInsets.fromLTRB(0, 600, 0, 22);

    expect(
      FreeformWindowInsets.normalize(
        insets: insets,
        viewSize: viewSize,
      ),
      const EdgeInsets.fromLTRB(0, 0, 0, 22),
    );
  });

  test('keeps valid freeform gesture insets', () {
    const insets = EdgeInsets.fromLTRB(8, 28, 8, 22);

    expect(
      FreeformWindowInsets.normalize(
        insets: insets,
        viewSize: viewSize,
      ),
      insets,
    );
  });

  test('removes an individually oversized bottom inset', () {
    const insets = EdgeInsets.fromLTRB(0, 24, 0, 360);

    expect(
      FreeformWindowInsets.normalize(
        insets: insets,
        viewSize: viewSize,
      ),
      const EdgeInsets.fromLTRB(0, 24, 0, 0),
    );
  });
}
