import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'attachment_storage_base.dart';

class PlatformAttachmentStorage implements AttachmentStorage {
  static String? overrideAppDocDir;

  Future<Directory> get _appDocDir async {
    if (overrideAppDocDir != null) {
      final dir = Directory(overrideAppDocDir!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<Directory> get _attachmentsDir async {
    final docDir = await _appDocDir;
    final dir = Directory(p.join(docDir.path, 'attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> get _signaturesDir async {
    final docDir = await _appDocDir;
    final dir = Directory(p.join(docDir.path, 'signatures'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<String> saveImage({
    required XFile file,
    required int jobId,
  }) async {
    final attachDir = await _attachmentsDir;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension =
        p.extension(file.path).isNotEmpty ? p.extension(file.path) : '.jpg';
    final fileName = 'job_${jobId}_$timestamp$extension';
    final targetPath = p.join(attachDir.path, fileName);

    final File sourceFile = File(file.path);
    if (await sourceFile.exists()) {
      await sourceFile.copy(targetPath);
    } else {
      // Fallback if file was provided via in-memory bytes or stream
      final bytes = await file.readAsBytes();
      final target = File(targetPath);
      await target.writeAsBytes(bytes);
    }

    return 'attachments/$fileName';
  }

  @override
  Future<String> saveSignature({
    required Uint8List bytes,
    required int jobId,
  }) async {
    final sigDir = await _signaturesDir;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'sig_${jobId}_$timestamp.png';
    final targetPath = p.join(sigDir.path, fileName);

    final File file = File(targetPath);
    await file.writeAsBytes(bytes);

    return 'signatures/$fileName';
  }

  @override
  Future<Uint8List?> getBytes(String relativePath) async {
    try {
      final docDir = await _appDocDir;
      final file = File(p.join(docDir.path, relativePath));
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }

  Future<File> getFileFromRelativePath(String relativePath) async {
    final docDir = await _appDocDir;
    return File(p.join(docDir.path, relativePath));
  }

  @override
  Future<bool> deleteFile(String relativePath) async {
    try {
      final docDir = await _appDocDir;
      final file = File(p.join(docDir.path, relativePath));
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<int> getTotalBytes() async {
    int total = 0;
    try {
      final docDir = await _appDocDir;
      final attachDir = Directory(p.join(docDir.path, 'attachments'));
      if (await attachDir.exists()) {
        await for (final file in attachDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (file is File) {
            total += await file.length();
          }
        }
      }

      final sigDir = Directory(p.join(docDir.path, 'signatures'));
      if (await sigDir.exists()) {
        await for (final file in sigDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (file is File) {
            total += await file.length();
          }
        }
      }
    } catch (_) {}
    return total;
  }

  @override
  Future<void> clearAll() async {
    try {
      final docDir = await _appDocDir;
      final attachDir = Directory(p.join(docDir.path, 'attachments'));
      if (await attachDir.exists()) {
        await attachDir.delete(recursive: true);
      }
      final sigDir = Directory(p.join(docDir.path, 'signatures'));
      if (await sigDir.exists()) {
        await sigDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
