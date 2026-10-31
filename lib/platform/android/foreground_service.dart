import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class AndroidForegroundListener {
  static void init() {
    if (!kIsWeb && Platform.isAndroid) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'suoro_drop_channel',
          channelName: 'Suoro P2P Drop Listener',
          channelDescription: 'Mendengarkan transfer file dan teks lokal',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          iconData: const NotificationIconData(
            resType: ResourceType.mipmap,
            resPrefix: ResourcePrefix.ic,
            name: 'launcher',
          ),
        ),
        iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
        foregroundTaskOptions: const ForegroundTaskOptions(
          interval: 5000,
          isOnceEvent: false,
          autoRunOnBoot: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    }
  }

  static Future<void> start() async {
    if (!kIsWeb && Platform.isAndroid) {
      if (!await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.startService(
          notificationTitle: 'Suoro Aktif',
          notificationText: 'Siap menerima file di jaringan lokal',
        );
      }
    }
  }

  static Future<void> stop() async {
    if (!kIsWeb && Platform.isAndroid) {
      await FlutterForegroundTask.stopService();
    }
  }
}
