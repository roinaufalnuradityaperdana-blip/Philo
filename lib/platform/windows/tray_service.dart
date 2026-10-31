import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class WindowsTrayService with TrayListener, WindowListener {
  static final WindowsTrayService instance = WindowsTrayService._();
  WindowsTrayService._();

  Future<void> init() async {
    if (!kIsWeb && Platform.isWindows) {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);

      trayManager.addListener(this);
      await trayManager.setIcon('assets/app_icon.ico');
      final menu = Menu(items: [
        MenuItem(key: 'show_window', label: 'Buka Suoro'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Keluar'),
      ]);
      await trayManager.setContextMenu(menu);
    }
  }

  @override
  void onWindowClose() async {
    if (Platform.isWindows) {
      await windowManager.hide();
    }
  }

  @override
  void onMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      await windowManager.destroy();
      exit(0);
    }
  }
}
