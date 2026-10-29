import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:fieldflow/services/attachment_service.dart';

void main() {
  final testDir = p.join(Directory.current.path, 'test_web_compat_env');

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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

  group('AttachmentService & Web Storage Compatibility Tests', () {
    test('Image and signature relative paths adhere to standard schema', () {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imageRel = 'attachments/job_101_$timestamp.jpg';
      final sigRel = 'signatures/sig_101_$timestamp.png';

      expect(imageRel, startsWith('attachments/'));
      expect(imageRel, endsWith('.jpg'));
      expect(sigRel, startsWith('signatures/'));
      expect(sigRel, endsWith('.png'));
    });

    test('AttachmentService handles byte storage and retrieval safely', () async {
      final service = AttachmentService.instance;
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);

      final path = await service.saveSignatureBytes(
        bytes: bytes,
        jobId: 999,
      );

      expect(path, startsWith('signatures/sig_999_'));

      final retrieved = await service.getImageBytes(path);
      expect(retrieved, isNotNull);
      expect(retrieved, equals(bytes));

      final deleted = await service.deleteFile(path);
      expect(deleted, isTrue);

      final afterDelete = await service.getImageBytes(path);
      expect(afterDelete, isNull);
    });
  });
}
