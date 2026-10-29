import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:fieldflow/services/attachment_service.dart';

void main() {
  final testDir = p.join(Directory.current.path, 'test_file_safety_env');

  setUpAll(() async {
    AttachmentService.overrideAppDocDir = testDir;
    final dir = Directory(testDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
  });

  tearDownAll(() async {
    AttachmentService.overrideAppDocDir = null;
    final dir = Directory(testDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('AttachmentService File Safety & Isolation Tests', () {
    final service = AttachmentService.instance;

    test(
        'Saves bytes to durable signatures directory and resolves relative path',
        () async {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final relPath = await service.saveSignatureBytes(
        bytes: sampleBytes,
        jobId: 101,
      );

      expect(relPath, startsWith('signatures'));
      expect(relPath, endsWith('.png'));

      final file = await service.getFileFromRelativePath(relPath);
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), sampleBytes);

      // Verify storage calculation reflects the saved file
      final bytesUsed = await service.getTotalStorageBytes();
      expect(bytesUsed, equals(8));

      // Delete file safely
      final deleted = await service.deleteFile(relPath);
      expect(deleted, isTrue);
      expect(await file.exists(), isFalse);

      // Verify deleting non-existent file returns false without throwing
      final deleteAgain = await service.deleteFile(relPath);
      expect(deleteAgain, isFalse);
    });

    test(
        'clearAllStorageFiles deletes attachments and signatures subdirectories',
        () async {
      await service.saveSignatureBytes(
        bytes: Uint8List.fromList([10, 20, 30]),
        jobId: 202,
      );

      expect(await service.getTotalStorageBytes(), greaterThan(0));

      await service.clearAllStorageFiles();

      expect(await service.getTotalStorageBytes(), equals(0));
    });
  });
}
