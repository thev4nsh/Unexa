import 'package:flutter_test/flutter_test.dart';
import 'package:unexa/core/constants/app_constants.dart';
import 'package:unexa/core/utils/date_formatter.dart';
import 'package:unexa/core/utils/validators.dart';
import 'package:unexa/data/models/announcement_model.dart';
import 'package:unexa/data/models/ban_model.dart';

void main() {
  group('domain validation', () {
    test('allows exact institute domains and subdomains', () {
      expect(
        Validators.isDomainAllowed('student@example.edu', ['example.edu']),
        isTrue,
      );
      expect(
        Validators.isDomainAllowed('student@mail.example.edu', ['example.edu']),
        isTrue,
      );
    });

    test('rejects unrelated domains', () {
      expect(
        Validators.isDomainAllowed('student@other.edu', ['example.edu']),
        isFalse,
      );
    });
  });

  group('ban hierarchy', () {
    const moderatorBan = BanModel(
      isActive: true,
      level: AppConstants.banLevelModerator,
      bannedByUid: 'mod',
      bannedByName: 'Moderator',
      bannedByRole: AppConstants.roleModerator,
      reason: 'Policy violation',
    );

    const adminBan = BanModel(
      isActive: true,
      level: AppConstants.banLevelAdmin,
      bannedByUid: 'admin',
      bannedByName: 'Admin',
      bannedByRole: AppConstants.roleAdmin,
      reason: 'Policy violation',
    );

    test('moderators can only remove moderator-level bans', () {
      expect(moderatorBan.canUnban(AppConstants.roleModerator), isTrue);
      expect(adminBan.canUnban(AppConstants.roleModerator), isFalse);
    });

    test('owner can remove every active ban level', () {
      expect(adminBan.canUnban(AppConstants.roleOwner), isTrue);
    });
  });

  group('schedule helpers', () {
    test('parses 12-hour times into minutes from midnight', () {
      expect(DateFormatter.parseMinutesFromMidnight('12:00 AM'), 0);
      expect(DateFormatter.parseMinutesFromMidnight('10:30 AM'), 630);
      expect(DateFormatter.parseMinutesFromMidnight('02:15 PM'), 855);
    });
  });

  group('announcement targeting', () {
    test('matches relevant academic scopes', () {
      const announcement = AnnouncementModel(
        id: 'a1',
        collegeId: 'college',
        title: 'Lab update',
        body: 'Bring your ID card.',
        authorName: 'Admin',
        targetScope: 'section',
        targetIds: ['sec-a'],
      );

      expect(announcement.isRelevantForStudent(sectionId: 'sec-a'), isTrue);
      expect(announcement.isRelevantForStudent(sectionId: 'sec-b'), isFalse);
    });
  });
}
