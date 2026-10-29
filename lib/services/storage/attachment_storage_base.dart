import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

abstract class AttachmentStorage {
  Future<String> saveImage({
    required XFile file,
    required int jobId,
  });

  Future<String> saveSignature({
    required Uint8List bytes,
    required int jobId,
  });

  Future<Uint8List?> getBytes(String relativePath);

  Future<bool> deleteFile(String relativePath);

  Future<int> getTotalBytes();

  Future<void> clearAll();
}

