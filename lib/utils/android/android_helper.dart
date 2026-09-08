import 'dart:convert';
import 'dart:ui';

import 'package:PiliPlus/utils/android/bindings.g.dart';
import 'package:PiliPlus/utils/android/backdrop_frame_notifier.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:jni/jni.dart';

abstract final class PiliAndroidHelper {
  static const _miuixNavigationChannel = MethodChannel(
    'com.aritxonly.hyperpiliplus/miuix_navigation',
  );
  static void Function(int index)? _onMiuixDestinationSelected;
  static final _backdropFrames = BackdropFrameNotifier(
    onFrameReady: () =>
        _miuixNavigationChannel.invokeMethod<void>('flutterFrameRendered'),
  );

  static void setMiuixDestinationHandler(void Function(int index)? handler) {
    _onMiuixDestinationSelected = handler;
    _miuixNavigationChannel.setMethodCallHandler((call) async {
      if (call.method == 'selectDestination' && call.arguments is int) {
        _onMiuixDestinationSelected?.call(call.arguments as int);
      }
    });
  }

  static Future<void> updateMiuixNavigation({
    required List<Map<String, String>> destinations,
    required int selectedIndex,
    required bool visible,
    required bool dark,
    required int primary,
    required int background,
    required int surface,
    required int surfaceContainer,
    required int onSurface,
    required int outline,
    required bool backdropSampling,
    required bool backdropDebug,
  }) {
    // Queue native visibility first; enabling the notifier immediately requests
    // a fresh sample, even if the surface is already idle.
    final update = _miuixNavigationChannel.invokeMethod<void>('update', {
      'destinations': destinations,
      'selectedIndex': selectedIndex,
      'visible': visible,
      'dark': dark,
      'primary': primary,
      'background': background,
      'surface': surface,
      'surfaceContainer': surfaceContainer,
      'onSurface': onSurface,
      'outline': outline,
      'backdropSampling': backdropSampling,
      'backdropDebug': backdropDebug,
    });
    _backdropFrames.configure(visible: visible && backdropSampling);
    return update;
  }

  static Future<void> hideMiuixNavigation() {
    _backdropFrames.configure(visible: false);
    return _miuixNavigationChannel.invokeMethod<void>('hide');
  }

  static Future<void> setMiuixOverlayOccluded(bool occluded) {
    final update = _miuixNavigationChannel.invokeMethod<void>(
      'setOverlayOccluded',
      occluded,
    );
    _backdropFrames.configure(occluded: occluded);
    return update;
  }

  static Future<void> setMiuixBackdropSamplingPaused(bool paused) {
    final update = _miuixNavigationChannel.invokeMethod<void>(
      'setBackdropSamplingPaused',
      paused,
    );
    _backdropFrames.configure(paused: paused);
    return update;
  }

  @pragma('vm:prefer-inline')
  static void back() => AndroidHelper.back();

  static void biliSendCommAntifraud(
    int action,
    int oid,
    int type,
    int rpId,
    int root,
    int parent,
    int ctime,
    String commentText,
    List pictures,
    String sourceId,
    int uid,
    String cookie,
  ) {
    final jCommentText = commentText.toJString();
    final jSourceId = sourceId.toJString();
    final jCookie = cookie.toJString();
    final jPictures = pictures.isEmpty
        ? null
        : jsonEncode(pictures).toJString();

    try {
      AndroidHelper.biliSendCommAntifraud(
        action,
        oid,
        type,
        rpId,
        root,
        parent,
        ctime,
        jCommentText,
        jPictures,
        jSourceId,
        uid,
        jCookie,
      );
    } catch (e) {
      Utils.reportError(e);
    } finally {
      jCommentText.release();
      jSourceId.release();
      jCookie.release();
      jPictures?.release();
    }
  }

  @pragma('vm:prefer-inline')
  static void openLinkVerifySettings() =>
      AndroidHelper.openLinkVerifySettings();

  static bool openMusic(String title, String? artist, String? album) {
    final jTitle = title.toJString();
    final jArtist = artist?.toJString();
    final jAlbum = album?.toJString();
    try {
      return AndroidHelper.openMusic(jTitle, jArtist, jAlbum);
    } finally {
      jTitle.release();
      jArtist?.release();
      jAlbum?.release();
    }
  }

  @pragma('vm:prefer-inline')
  static void enterPip(
    int width,
    int height, {
    required bool autoEnter,
    required bool isLive,
    required bool isPlaying,
  }) => AndroidHelper.enterPip(
    PlatformDispatcher.instance.engineId!,
    width,
    height,
    autoEnter,
    isLive,
    isPlaying,
  );

  @pragma('vm:prefer-inline')
  static void disableAutoEnterPip() =>
      AndroidHelper.disableAutoEnterPip(PlatformDispatcher.instance.engineId!);

  static (int, int)? maxScreenSize() {
    final jIArr = AndroidHelper.maxScreenSize();
    if (jIArr != null) {
      try {
        return (jIArr[0], jIArr[1]);
      } finally {
        jIArr.release();
      }
    }
    return null;
  }

  static void createShortcut(String id, String uri, String label, String path) {
    final jId = id.toJString();
    final jUri = uri.toJString();
    final jLabel = label.toJString();
    final jPath = path.toJString();
    try {
      AndroidHelper.createShortcut(jId, jUri, jLabel, jPath);
    } finally {
      jId.release();
      jUri.release();
      jLabel.release();
      jPath.release();
    }
  }
}
