import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_paths.dart';
import '../models/document_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

/// Repository for official college PDF documents (Timetable PDF, Holiday List PDF).
class DocumentRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentRepository(this._firestore, this._storage);

  /// Stream official documents for a college
  Stream<List<DocumentModel>> streamDocuments(String collegeId) {
    return _firestore
        .collection(FirestorePaths.documents(collegeId))
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DocumentModel.fromFirestore(d)).toList());
  }

  /// Fetch the currently active document of a given type (timetable_pdf, holiday_pdf).
  Future<DocumentModel?> getActiveDocument(String collegeId, String type) async {
    final snap = await _firestore
        .collection(FirestorePaths.documents(collegeId))
        .where('type', isEqualTo: type)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return DocumentModel.fromFirestore(snap.docs.first);
  }

  /// Publish (or replace) the official PDF of a given type with versioning + audit log.
  /// Replaces any existing active document of that type so Routine/Holiday buttons
  /// always open the latest official version.
  Future<DocumentModel> publishOfficialDocument({
    required String collegeId,
    required String type,
    required String title,
    required File file,
    required UserModel actor,
  }) async {
    if (!file.path.toLowerCase().endsWith('.pdf')) {
      throw const FormatException('Only PDF files can be published as official documents.');
    }

    final existing = await getActiveDocument(collegeId, type);
    final nextVersion = (existing?.version ?? 0) + 1;

    final docRef = _firestore.collection(FirestorePaths.documents(collegeId)).doc();
    final storagePath =
        FirestorePaths.storageDocument(collegeId, docRef.id, 'v$nextVersion.pdf');

    // 1. Upload the actual PDF to tenant-scoped Storage
    final uploadTask = await _storage.ref(storagePath).putFile(
          file,
          SettableMetadata(contentType: 'application/pdf'),
        );
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // 2. Retire the previous version (if any)
    if (existing != null) {      await _firestore
          .doc(FirestorePaths.document(collegeId, existing.id))
          .update({'isActive': false, 'replacedByDocId': docRef.id});
    }

    // 3. Publish new metadata
    final docModel = DocumentModel(
      id: docRef.id,
      collegeId: collegeId,
      type: type,
      title: title,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      version: nextVersion,
      uploadedBy: actor.uid,
      uploadedAt: DateTime.now(),
      isActive: true,
    );
    await docRef.set(docModel.toMap());

    // 4. Append audit log
    await _firestore.collection(FirestorePaths.auditLogs(collegeId)).add({
      'collegeId': collegeId,
      'actorUid': actor.uid,
      'actorName': actor.displayName,
      'actorEmail': actor.email,
      'actorRole': actor.role,
      'action': existing == null ? AppConstants.auditDocumentUploaded : AppConstants.auditDocumentReplaced,
      'targetUid': docRef.id,
      'reason': 'Published $title v$nextVersion',
      'timestamp': FieldValue.serverTimestamp(),
    });

    return docModel;
  }

  /// Upload and publish an official PDF document
  Future<void> uploadDocument({
    required String collegeId,
    required String type,
    required String title,
    required File file,
    required String fileName,
    required String actorUid,
  }) async {
    final docRef = _firestore.collection(FirestorePaths.documents(collegeId)).doc();
    final storagePath = FirestorePaths.storageDocument(collegeId, docRef.id, fileName);

    // Upload file to Firebase Storage
    final uploadTask = await _storage.ref(storagePath).putFile(
      file,
      SettableMetadata(contentType: 'application/pdf'),
    );
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // Store metadata in Firestore
    final docModel = DocumentModel(
      id: docRef.id,
      collegeId: collegeId,
      type: type,
      title: title,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      uploadedBy: actorUid,
      uploadedAt: DateTime.now(),
      isActive: true,
    );

    await docRef.set(docModel.toMap());

    // Audit log
    await _firestore.collection(FirestorePaths.auditLogs(collegeId)).add({
      'collegeId': collegeId,
      'actorUid': actorUid,
      'actorName': 'Staff',
      'actorEmail': '',
      'actorRole': 'staff',
      'action': 'DOCUMENT_UPLOADED',
      'reason': 'Uploaded $title',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Delete document
  Future<void> deleteDocument(String collegeId, String documentId, String storagePath) async {
    await _firestore.doc(FirestorePaths.document(collegeId, documentId)).update({
      'isActive': false,
    });
    try {
      if (storagePath.isNotEmpty) {
        await _storage.ref(storagePath).delete();
      }
    } catch (_) {}
  }
}

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final storage = ref.watch(firebaseStorageProvider);
  return DocumentRepository(firestore, storage);
});
