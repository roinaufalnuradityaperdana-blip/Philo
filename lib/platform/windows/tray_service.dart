import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class WindowsTrayService with TrayListener, WindowListener {
  static final WindowsTrayService instance = WindowsTrayService._();
  WindowsTrayService._();

  Future<void> init() async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        await windowManager.ensureInitialized();
        windowManager.addListener(this);
        await windowManager.setPreventClose(true);
      } catch (e) {
        debugPrint('window_manager init error: $e');
      }
    }
  }

  @override
  void onWindowClose() async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        await windowManager.hide();
      } catch (e) {
        debugPrint('windowManager.hide error: $e');
      }
    }
  }

  @override
  void onMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      try {
        await windowManager.show();
        await windowManager.focus();
      } catch (e) {
        debugPrint('windowManager.show error: $e');
      }
    } else if (menuItem.key == 'exit_app') {
      try {
        await windowManager.destroy();
      } catch (e) {
        debugPrint('windowManager.destroy error: $e');
      }
      exit(0);
    }
  }
}
