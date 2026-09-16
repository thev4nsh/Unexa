import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/firestore_paths.dart';
import '../models/calendar_event_model.dart';
import '../services/firebase_service.dart';

/// Repository for academic calendar events and holidays.
class CalendarRepository {
  final FirebaseFirestore _firestore;

  CalendarRepository(this._firestore);

  /// Stream all events for a college, ordered by date
  Stream<List<CalendarEventModel>> streamEvents(String collegeId) {
    return _firestore
        .collection(FirestorePaths.calendarEvents(collegeId))
        .orderBy('date', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CalendarEventModel.fromFirestore(d)).toList());
  }

  /// Check if today or a given date is a holiday in the college
  Stream<CalendarEventModel?> streamHolidayForDate(String collegeId, DateTime date) {
    return streamEvents(collegeId).map((events) {
      for (final event in events) {
        if (event.isHoliday &&
            event.date.year == date.year &&
            event.date.month == date.month &&
            event.date.day == date.day) {
          return event;
        }
      }
      return null;
    });
  }

  /// Add a calendar event or holiday (Staff)
  Future<void> addEvent(CalendarEventModel event) async {
    await _firestore.collection(FirestorePaths.calendarEvents(event.collegeId)).add(event.toMap());
  }

  /// Delete a calendar event (Staff)
  Future<void> deleteEvent(String collegeId, String eventId) async {
    await _firestore.doc(FirestorePaths.calendarEvent(collegeId, eventId)).delete();
  }
}

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return CalendarRepository(firestore);
});
