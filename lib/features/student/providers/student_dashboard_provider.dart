import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/announcement_model.dart';
import '../../../data/models/calendar_event_model.dart';
import '../../../data/models/document_model.dart';
import '../../../data/models/timetable_model.dart';
import '../../../data/repositories/academic_repository.dart';
import '../../../data/repositories/announcement_repository.dart';
import '../../../data/repositories/calendar_repository.dart';
import '../../../data/repositories/document_repository.dart';
import '../../../data/repositories/timetable_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Ticks every 30s and CHANGES VALUE at midnight — providers watching it
/// re-stream the right day's classes the moment the date rolls over.
final todayClockProvider = StreamProvider<DateTime>((ref) {
  late StreamSubscription<void> sub;
  final controller = StreamController<DateTime>();
  Timer? timer;

  void schedule() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    timer = Timer(nextMidnight.difference(now), () {
      if (!controller.isClosed) controller.add(DateTime.now());
      schedule();
    });
  }

  controller.onListen = () {
    controller.add(DateTime.now());
    // 30s heartbeat keeps "ongoing" times fresh; cheap and battery-friendly.
    timer = Timer.periodic(const Duration(seconds: 30), (_) {});
    schedule();
  };
  ref.onDispose(() {
    timer?.cancel();
    sub.cancel();
    controller.close();
  });
  sub = const Stream.empty().listen(null);
  return controller.stream;
});

/// Stream today's holiday if one is configured for today
final todayHolidayProvider = StreamProvider<CalendarEventModel?>((ref) {
  final user = ref.watch(currentUserModelProvider).value;
  if (user == null || user.collegeId.isEmpty) return Stream.value(null);

  final today = ref.watch(todayClockProvider).value ?? DateTime.now();
  return ref.watch(calendarRepositoryProvider).streamHolidayForDate(user.collegeId, today);
});

/// Stream of today's classes for the current student — scoped by department,
/// batch and section, and automatically rolls over at midnight.
final todayClassesProvider = StreamProvider<List<TimetableEntryModel>>((ref) {
  final user = ref.watch(currentUserModelProvider).value;
  if (user == null || user.collegeId.isEmpty) return Stream.value([]);

  final now = ref.watch(todayClockProvider).value ?? DateTime.now();
  final day = DateFormatter.currentDayName(now);
  return ref.watch(timetableRepositoryProvider).streamScopedTimetable(
        collegeId: user.collegeId,
        day: day,
        departmentId: user.departmentId,
        batchId: user.batchId,
        sectionId: user.sectionId,
      );
});

/// Resolves the current user's section document id from its display name.
/// Firestore timetable entries store sectionId; onboarding stores the name.
final _userSectionIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserModelProvider).value;
  final batchId = user?.batchId;
  final sectionName = user?.sectionName;
  if (user == null ||
      user.collegeId.isEmpty ||
      batchId == null ||
      batchId.isEmpty ||
      sectionName == null ||
      sectionName.isEmpty) {
    return null;
  }
  final sections = await ref.watch(
    sectionsProvider((user.collegeId, batchId)).future,
  );
  for (final section in sections) {
    if (section.name.toLowerCase() == sectionName.toLowerCase()) {
      return section.id;
    }
  }
  return null;
});

/// Correctly scoped classes for students AND moderators (staff see the
/// department/batch/section they are onboarded into).
final homeClassesProvider = StreamProvider<List<TimetableEntryModel>>((ref) {
  final user = ref.watch(currentUserModelProvider).value;
  if (user == null || user.collegeId.isEmpty) return Stream.value([]);

  final now = ref.watch(todayClockProvider).value ?? DateTime.now();
  final day = DateFormatter.currentDayName(now);
  final sectionId = ref.watch(_userSectionIdProvider).value;

  return ref.watch(timetableRepositoryProvider).streamScopedTimetable(
        collegeId: user.collegeId,
        day: day,
        departmentId: user.departmentId,
        batchId: user.batchId,
        sectionId: sectionId,
      );
});

/// Next upcoming class calculation
final nextUpcomingClassProvider = Provider<TimetableEntryModel?>((ref) {
  final classes = ref.watch(todayClassesProvider).value ?? [];
  if (classes.isEmpty) return null;

  final now = DateTime.now();
  final currentMinutes = now.hour * 60 + now.minute;

  for (final entry in classes) {
    final startMin = DateFormatter.parseMinutesFromMidnight(entry.startTime);
    final endMin = DateFormatter.parseMinutesFromMidnight(entry.endTime);
    if (startMin != null && endMin != null) {
      if (currentMinutes <= endMin) {
        return entry; // This class is either ongoing or the next one starting
      }
    }
  }
  return null;
});

/// Stream recent announcements for dashboard preview
final recentAnnouncementsProvider = StreamProvider<List<AnnouncementModel>>((ref) {
  final user = ref.watch(currentUserModelProvider).value;
  if (user == null || user.collegeId.isEmpty) return Stream.value([]);

  return ref.watch(announcementRepositoryProvider).streamStudentAnnouncements(
        collegeId: user.collegeId,
        departmentId: user.departmentId,
        batchId: user.batchId,
        sectionId: user.sectionId,
      );
});

/// Stream upcoming calendar events
final upcomingCalendarEventsProvider = StreamProvider<List<CalendarEventModel>>((ref) {
  final user = ref.watch(currentUserModelProvider).value;
  if (user == null || user.collegeId.isEmpty) return Stream.value([]);

  return ref.watch(calendarRepositoryProvider).streamEvents(user.collegeId).map((events) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return events.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return !eventDate.isBefore(startOfToday);
    }).take(10).toList();
  });
});

/// Stream official documents published for the student's college
final officialDocumentsProvider = StreamProvider<List<DocumentModel>>((ref) {
  final user = ref.watch(currentUserModelProvider).value;
  if (user == null || user.collegeId.isEmpty) return Stream.value([]);

  return ref.watch(documentRepositoryProvider).streamDocuments(user.collegeId);
});
