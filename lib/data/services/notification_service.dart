import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/date_formatter.dart';
import '../models/announcement_model.dart';
import '../models/timetable_model.dart';

/// Complete notification service for a Firebase-only, serverless UNEXA build.
///
/// Features:
/// - Instant real-time Firestore announcement notifications for students.
/// - Immediate account verification status updates.
/// - Timezone-aware local scheduling for daily 7:00 AM class schedule briefings.
/// - Automatic 1-hour before class/lab schedule reminders without external backend servers.
class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  StreamSubscription<QuerySnapshot>? _announcementSubscription;
  StreamSubscription<QuerySnapshot>? _documentSubscription;
  StreamSubscription<DocumentSnapshot>? _verificationSubscription;
  DateTime? _subscriptionStartTime;
  final Set<String> _seenDocumentIds = {};

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
    } catch (e) {
      if (kDebugMode) print('Timezone initialization note: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (kDebugMode) {
          print('UNEXA local notification tapped: ${response.payload}');
        }
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      const generalChannel = AndroidNotificationChannel(
        'unexa_local_channel',
        'UNEXA Campus Updates',
        description: 'Instant announcements and campus update alerts.',
        importance: Importance.high,
      );

      const scheduleChannel = AndroidNotificationChannel(
        'unexa_schedule_channel',
        'UNEXA Timetable & Class Reminders',
        description: 'Daily morning briefing and 1-hour before class reminders.',
        importance: Importance.high,
      );

      await androidPlugin?.createNotificationChannel(generalChannel);
      await androidPlugin?.createNotificationChannel(scheduleChannel);
    }

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission() ?? true;
    }

    if (Platform.isIOS) {
      final iosPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      return await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
    }

    if (Platform.isMacOS) {
      final macPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();
      return await macPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
    }

    return true;
  }

  /// Show an immediate high-priority notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'unexa_local_channel',
      'UNEXA Campus Updates',
      channelDescription: 'Instant announcements and campus update alerts.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _localNotifications.show(
      id: id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Schedule a daily morning briefing (e.g. 7:00 AM) listing today's schedule
  Future<void> scheduleDailyBriefing({
    required int hour,
    required int minute,
    required String title,
    required String body,
    int id = 7000,
  }) async {
    await initialize();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'unexa_schedule_channel',
      'UNEXA Timetable & Class Reminders',
      channelDescription: 'Daily morning briefing and 1-hour before class reminders.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_briefing',
    );
  }

  /// Schedule a 1-hour reminder before a class or lab session
  Future<void> scheduleClassReminder({
    required int id,
    required DateTime classTime,
    required String subjectName,
    required String room,
    bool isLab = false,
  }) async {
    await initialize();

    final reminderTime = classTime.subtract(const Duration(hours: 1));
    if (reminderTime.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

    final title = isLab ? '🧪 Lab Reminder' : '⏰ Class Reminder';
    final body = '$subjectName starts in 1 hour${room.isNotEmpty ? ' in $room' : ''}.';

    const androidDetails = AndroidNotificationDetails(
      'unexa_schedule_channel',
      'UNEXA Timetable & Class Reminders',
      channelDescription: 'Daily morning briefing and 1-hour before class reminders.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'class_reminder',
    );
  }

  /// Synchronize today's class schedule: 7 AM briefing + 1-hour upcoming reminders
  Future<void> syncClassReminders(List<TimetableEntryModel> todayClasses) async {
    if (todayClasses.isEmpty) return;

    // 1. Build and schedule daily morning summary
    final summaryBuffer = StringBuffer('Today\'s classes:\n');
    for (final entry in todayClasses) {
      summaryBuffer.writeln('${entry.startTime} — ${entry.subjectName}${entry.isLab ? ' (Lab)' : ''}');
    }

    await scheduleDailyBriefing(
      hour: 7,
      minute: 0,
      title: '📚 Good Morning!',
      body: summaryBuffer.toString().trim(),
    );

    // 2. Schedule 1-hour advance reminders for each class today
    final now = DateTime.now();
    for (var i = 0; i < todayClasses.length; i++) {
      final entry = todayClasses[i];
      if (!entry.isActive) continue;

      final startMinutes = DateFormatter.parseMinutesFromMidnight(entry.startTime);
      if (startMinutes == null) continue;

      final classHour = startMinutes ~/ 60;
      final classMinute = startMinutes % 60;
      final classDateTime = DateTime(now.year, now.month, now.day, classHour, classMinute);

      await scheduleClassReminder(
        id: 2000 + i,
        classTime: classDateTime,
        subjectName: entry.subjectName,
        room: entry.room,
        isLab: entry.isLab,
      );
    }
  }

  /// Real-time Firestore stream listener for announcements
  void startAnnouncementSync({
    required FirebaseFirestore firestore,
    required String collegeId,
    String? departmentId,
    String? batchId,
    String? sectionId,
  }) {
    _announcementSubscription?.cancel();
    _subscriptionStartTime = DateTime.now();

    _announcementSubscription = firestore
        .collection(FirestorePaths.announcements(collegeId))
        .where('isPublished', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final announcement = AnnouncementModel.fromFirestore(
            change.doc,
          );

          if (announcement.createdAt != null &&
              _subscriptionStartTime != null &&
              announcement.createdAt!.isAfter(_subscriptionStartTime!)) {
            if (announcement.isRelevantForStudent(
              departmentId: departmentId,
              batchId: batchId,
              sectionId: sectionId,
            )) {
              showLocalNotification(
                title: '📢 ${announcement.title}',
                body: announcement.body,
                payload: '/student/announcements',
              );
            }
          }
        }
      }
    });
  }

  /// Real-time Firestore listener for newly published official PDFs
  /// (Routine / Holiday). Students get an instant notification when staff
  /// upload or replace an official document.
  void startOfficialDocumentSync({
    required FirebaseFirestore firestore,
    required String collegeId,
  }) {
    _documentSubscription?.cancel();
    _subscriptionStartTime ??= DateTime.now();

    _documentSubscription = firestore
        .collection(FirestorePaths.documents(collegeId))
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final docId = change.doc.id;
          if (_seenDocumentIds.contains(docId)) continue;
          _seenDocumentIds.add(docId);

          // Only notify for documents that appeared after we started listening.
          final uploadedAt = (data['uploadedAt'] as Timestamp?)?.toDate();
          if (uploadedAt == null ||
              !_isAfterStartup(uploadedAt, _subscriptionStartTime!)) {
            continue;
          }

          final type = (data['type'] as String?) ?? '';
          final title = type == 'holiday_pdf'
              ? '🏖️ Holiday list updated'
              : type == 'timetable_pdf'
                  ? '📅 Routine updated'
                  : '📄 New document published';

          showLocalNotification(
            title: title,
            body: (data['title'] as String?) ?? 'Tap to view in Documents.',
            payload: '/student/documents',
          );
        }
      }
    });
  }

  bool _isAfterStartup(DateTime time, DateTime startTime) {
    // Small tolerance for clock skew between write and snapshot delivery.
    return time.isAfter(startTime.subtract(const Duration(minutes: 1)));
  }

  /// Real-time listener for verification approval
  void startVerificationStatusSync({
    required FirebaseFirestore firestore,
    required String collegeId,
    required String uid,
    required VoidCallback onApproved,
  }) {
    _verificationSubscription?.cancel();
    _verificationSubscription = firestore
        .doc(FirestorePaths.user(collegeId, uid))
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        final status = data?['accountStatus'] as String?;
        if (status == 'active') {
          showLocalNotification(
            title: '🎉 Account Verified!',
            body: 'Your student account has been approved by your institute.',
            payload: '/student/home',
          );
          onApproved();
        }
      }
    });
  }

  Future<void> cancelNotification(int id) async {
    await initialize();
    await _localNotifications.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await initialize();
    await _localNotifications.cancelAll();
  }

  void stopAllSync() {
    _announcementSubscription?.cancel();
    _announcementSubscription = null;
    _documentSubscription?.cancel();
    _documentSubscription = null;
    _verificationSubscription?.cancel();
    _verificationSubscription = null;
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(() => service.stopAllSync());
  return service;
});
