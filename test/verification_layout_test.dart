import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unexa/data/models/user_model.dart';
import 'package:unexa/data/models/verification_request_model.dart';
import 'package:unexa/features/admin/presentation/verification_requests_screen.dart';
import 'package:unexa/features/admin/providers/verification_management_provider.dart';
import 'package:unexa/features/auth/providers/auth_provider.dart';

VerificationRequestModel _req(String id, String name, String status) {
  return VerificationRequestModel(
    id: id,
    uid: 'uid-$id',
    email: '$id@test.com',
    displayName: name,
    collegeId: 'c1',
    status: status,
    requestedAt: DateTime(2026, 1, 1),
  );
}

class _IdleController extends VerificationController {
  @override
  FutureOr<void> build() {}
}

Future<void> _pump(
  WidgetTester tester,
  UserModel admin, {
  List<VerificationRequestModel> requests = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserModelProvider.overrideWith((ref) => Stream.value(admin)),
        filteredVerificationRequestsProvider.overrideWith((ref) {
          return AsyncValue.data(requests);
        }),
        verificationControllerProvider.overrideWith(() => _IdleController()),
      ],
      child: const MaterialApp(home: VerificationRequestsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _segment(String label) => find.descendant(
      of: find.byType(SegmentedButton<String>),
      matching: find.text(label),
    );

UserModel _admin() => UserModel(
      uid: 'admin1',
      email: 'admin@test.com',
      displayName: 'Admin One',
      collegeId: 'c1',
      role: 'admin',
      accountStatus: 'active',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets(
    'verification tabs render with zero overflow on a 320dp screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 560));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final errors = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);
      addTearDown(() => FlutterError.onError = original);

      await _pump(
        tester,
        _admin(),
        requests: [
          _req('p1', 'Pat Pending', 'pending'),
          _req('a1', 'Ari Approved', 'active'),
          _req('b1', 'Ben Banned', 'banned'),
          _req('r1', 'Ria Rejected', 'rejected'),
        ],
      );

      // Visit every base tab — each renders a different action row.
      for (final label in ['Approved', 'Banned', 'Rejected', 'Pending']) {
        await tester.tap(_segment(label), warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      if (errors.isNotEmpty) {
        // Dump the full diagnostic (with the creator chain) to a file so the
        // overflowing widget can be identified exactly.
        // ignore: avoid_print
        print('OVERFLOW_DIAGNOSTIC_START');
        // ignore: avoid_print
        print(errors.first.toString());
        // ignore: avoid_print
        print('OVERFLOW_DIAGNOSTIC_END');
      }
      expect(errors, isEmpty);
    },
  );

  testWidgets(
    'verification All Users tab renders with zero overflow on a 320dp screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 560));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(tester, _admin(), requests: [
        _req('a1', 'Ari Approved', 'active'),
      ]);

      await tester.tap(_segment('All users'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'open keyboard + empty result set renders with zero overflow (all tabs)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 560));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Simulate the software keyboard covering the bottom half.
      tester.view.viewInsets = FakeViewPadding(bottom: 280);
      addTearDown(tester.view.reset);

      final errors = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);
      addTearDown(() => FlutterError.onError = original);

      // Empty list = the "all caught up" empty state that the search flow
      // surfaces on every tab once a query filters everything out.
      await _pump(tester, _admin(), requests: const []);

      // Focus the search field exactly like a user tapping it.
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();

      // Visit each tab with the keyboard still open.
      for (final label in ['Approved', 'Banned', 'Rejected', 'Pending']) {
        await tester.tap(_segment(label), warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      if (errors.isNotEmpty) {
        // ignore: avoid_print
        print('KEYBOARD_OVERFLOW_DIAGNOSTIC_START');
        // ignore: avoid_print
        print(errors.first.toString());
        // ignore: avoid_print
        print('KEYBOARD_OVERFLOW_DIAGNOSTIC_END');
      }
      expect(errors, isEmpty);
    },
  );
}
