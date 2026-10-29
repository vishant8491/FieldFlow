import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'storage/attachment_storage.dart';

class AttachmentService {
  static final AttachmentService instance = AttachmentService._internal();
  AttachmentService._internal();

  static String? get overrideAppDocDir =>
      PlatformAttachmentStorage.overrideAppDocDir;
  static set overrideAppDocDir(String? path) =>
      PlatformAttachmentStorage.overrideAppDocDir = path;

  final PlatformAttachmentStorage _storage = PlatformAttachmentStorage();
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from camera or gallery
  Future<XFile?> pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      return file;
    } catch (e) {
      // Handles permission rejection or picker cancellation
      return null;
    }
  }

  /// Android activity-destruction lost data recovery
  Future<LostDataResponse?> retrieveLostData() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return await _picker.retrieveLostData();
      }
    } catch (_) {}
    return null;
  }

  /// Saves chosen image into durable app-managed storage and returns relative path
  Future<String> saveImageToPersistentStorage({
    required XFile file,
    required int jobId,
  }) async {
    return await _storage.saveImage(file: file, jobId: jobId);
  }

  /// Saves raw signature image bytes (e.g. PNG) into durable signatures storage
  Future<String> saveSignatureBytes({
    required Uint8List bytes,
    required int jobId,
  }) async {
    return await _storage.saveSignature(bytes: bytes, jobId: jobId);
  }

  /// Retrieves image / signature bytes from relative path across platforms
  Future<Uint8List?> getImageBytes(String relativePath) async {
    return await _storage.getBytes(relativePath);
  }

  /// Resolves relative path to native File on IO platforms (for backward compatibility / tests)
  Future<dynamic> getFileFromRelativePath(String relativePath) async {
    return await (_storage as dynamic).getFileFromRelativePath(relativePath);
  }

  /// Deletes file safely from storage
  Future<bool> deleteFile(String relativePath) async {
    return await _storage.deleteFile(relativePath);
  }

  /// Calculates total bytes used by attachments and signatures
  Future<int> getTotalStorageBytes() async {
    return await _storage.getTotalBytes();
  }

  /// Deletes all saved files on complete app reset
  Future<void> clearAllStorageFiles() async {
    await _storage.clearAll();
  }
}
