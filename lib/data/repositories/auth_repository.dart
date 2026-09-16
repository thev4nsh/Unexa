import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/validators.dart';
import '../models/college_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

/// Authentication Repository handling Google Sign-In, Domain Validation, and User State.
class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthRepository(this._auth, this._firestore);

  /// Stream of current Firebase Auth User
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current authenticated Firebase User
  User? get currentUser => _auth.currentUser;

  /// Sign In with Google and validate selected college institute domain.
  Future<UserModel> signInWithGoogle({required CollegeModel selectedCollege}) async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException('Google Sign-In was cancelled.');
      }

      final email = googleUser.email.trim().toLowerCase();

      // Check institute domain if allowedEmailDomains is configured
      if (selectedCollege.allowedEmailDomains.isNotEmpty) {
        final isDomainValid = Validators.isDomainAllowed(email, selectedCollege.allowedEmailDomains);
        if (!isDomainValid) {
          await _googleSignIn.signOut();
          final userDomain = Validators.extractEmailDomain(email) ?? 'unknown';
          throw AuthException.unauthorizedDomain(userDomain, selectedCollege.allowedEmailDomains);
        }
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw const AuthException('Failed to retrieve signed in user.');
      }

      // Check if user document already exists in this college
      final userDocRef = _firestore.doc(FirestorePaths.user(selectedCollege.id, user.uid));
      final userSnap = await userDocRef.get();

      if (!userSnap.exists) {
        // Create initial pending student document
        final newUser = UserModel(
          uid: user.uid,
          email: email,
          displayName: user.displayName ?? googleUser.displayName ?? 'Student',
          photoUrl: user.photoURL ?? googleUser.photoUrl,
          collegeId: selectedCollege.id,
          role: AppConstants.roleStudent,
          accountStatus: AppConstants.statusPending,
          createdAt: DateTime.now(),
        );

        await userDocRef.set(newUser.toMap());

        // Create verification request entry
        final reqRef = _firestore.doc(FirestorePaths.verificationRequest(selectedCollege.id, user.uid));
        await reqRef.set({
          'uid': user.uid,
          'email': email,
          'displayName': newUser.displayName,
          'photoUrl': newUser.photoUrl,
          'collegeId': selectedCollege.id,
          'status': AppConstants.statusPending,
          'requestedAt': FieldValue.serverTimestamp(),
        });

        await _syncGlobalUserIndex(
          uid: user.uid,
          collegeId: selectedCollege.id,
          accountStatus: AppConstants.statusPending,
        );

        return newUser;
      } else {
        // Existing user: check if account was banned or rejected
        final existingUser = UserModel.fromFirestore(userSnap);

        await _syncGlobalUserIndex(
          uid: user.uid,
          collegeId: selectedCollege.id,
          accountStatus: existingUser.accountStatus,
        );

        return existingUser;
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthException.fromFirebase(e);
    }
  }

  /// Authoritative Stream of the active user model in their college
  Stream<UserModel?> streamUser(String collegeId, String uid) {
    return _firestore
        .doc(FirestorePaths.user(collegeId, uid))
        .snapshots()
        .map((snap) => snap.exists ? UserModel.fromFirestore(snap) : null);
  }

  /// Lookup user's assigned collegeId from the global user mapping
  Future<String?> lookupUserCollegeId(String uid) async {
    try {
      final doc = await _firestore.collection(FirestorePaths.globalUsers).doc(uid).get();
      if (doc.exists) {
        return doc.data()?['collegeId'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Save academic onboarding information (Department, Batch, Year, Section)
  Future<void> completeOnboarding({
    required String collegeId,
    required String uid,
    required String departmentId,
    required String departmentName,
    required String batchId,
    required String batchName,
    int? year,
    String? sectionId,
    String? sectionName,
  }) async {
    final userRef = _firestore.doc(FirestorePaths.user(collegeId, uid));
    await userRef.update({
      'departmentId': departmentId,
      'departmentName': departmentName,
      'batchId': batchId,
      'batchName': batchName,
      'year': ?year,
      'sectionId': ?sectionId,
      'sectionName': ?sectionName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> _syncGlobalUserIndex({
    required String uid,
    required String collegeId,
    required String accountStatus,
  }) async {
    try {
      await _firestore.collection(FirestorePaths.globalUsers).doc(uid).set({
        'collegeId': collegeId,
        'accountStatus': accountStatus,
      }, SetOptions(merge: true));
    } catch (_) {
      // The college-scoped user document remains authoritative; this index is only for faster startup routing.
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  return AuthRepository(auth, firestore);
});
