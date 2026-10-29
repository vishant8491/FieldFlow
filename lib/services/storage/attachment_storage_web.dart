import 'dart:typed_data';
import 'package:idb_shim/idb_browser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'attachment_storage_base.dart';

class PlatformAttachmentStorage implements AttachmentStorage {
  static String? overrideAppDocDir;
  static const String _dbName = 'fieldflow_attachments.db';
  static const String _storeName = 'binary_files';
  static const int _version = 1;

  Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final factory = idbFactoryBrowser;
    _db = await factory.open(
      _dbName,
      version: _version,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final db = event.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      },
    );
    return _db!;
  }

  @override
  Future<String> saveImage({
    required XFile file,
    required int jobId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension =
        p.extension(file.name).isNotEmpty ? p.extension(file.name) : '.jpg';
    final fileName = 'job_${jobId}_$timestamp$extension';
    final relativePath = 'attachments/$fileName';

    final bytes = await file.readAsBytes();
    final db = await _getDb();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    await store.put(bytes, relativePath);
    await txn.completed;

    return relativePath;
  }

  @override
  Future<String> saveSignature({
    required Uint8List bytes,
    required int jobId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'sig_${jobId}_$timestamp.png';
    final relativePath = 'signatures/$fileName';

    final db = await _getDb();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    await store.put(bytes, relativePath);
    await txn.completed;

    return relativePath;
  }

  @override
  Future<Uint8List?> getBytes(String relativePath) async {
    try {
      final db = await _getDb();
      final txn = db.transaction(_storeName, idbModeReadOnly);
      final store = txn.objectStore(_storeName);
      final record = await store.getObject(relativePath);
      await txn.completed;

      if (record is Uint8List) {
        return record;
      } else if (record is List<int>) {
        return Uint8List.fromList(record);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> deleteFile(String relativePath) async {
    try {
      final db = await _getDb();
      final txn = db.transaction(_storeName, idbModeReadWrite);
      final store = txn.objectStore(_storeName);
      await store.delete(relativePath);
      await txn.completed;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> getTotalBytes() async {
    int total = 0;
    try {
      final db = await _getDb();
      final txn = db.transaction(_storeName, idbModeReadOnly);
      final store = txn.objectStore(_storeName);
      final records = await store.getAll();
      await txn.completed;

      for (final r in records) {
        if (r is List<int>) {
          total += r.length;
        }
      }
    } catch (_) {}
    return total;
  }

  @override
  Future<void> clearAll() async {
    try {
      final db = await _getDb();
      final txn = db.transaction(_storeName, idbModeReadWrite);
      final store = txn.objectStore(_storeName);
      await store.clear();
      await txn.completed;
    } catch (_) {}
  }
}
