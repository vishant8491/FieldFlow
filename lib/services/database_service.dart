import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'db_factory_helper.dart';
import '../models/customer.dart';
import '../models/service_job.dart';
import '../models/checklist_item.dart';
import '../models/attachment.dart';
import '../models/job_note.dart';
import '../models/status_event.dart';
import '../models/sign_off.dart';
import '../models/checklist_template.dart';
import '../models/template_item.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  static const String databaseName = 'fieldflow.db';
  static const int databaseVersion = 1;
  static String? overrideDatabasePath;

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final String path;
    if (overrideDatabasePath != null) {
      path = overrideDatabasePath!;
    } else if (kIsWeb) {
      initWebDatabaseFactory();
      path = databaseName;
    } else {
      final databasesPath = await getDatabasesPath();
      path = p.join(databasesPath, databaseName);
    }

    return await openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys in SQLite
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Customers
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT
      )
    ''');

    // 2. Jobs
    await db.execute('''
      CREATE TABLE jobs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        customerId INTEGER NOT NULL,
        address TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        locationAccuracy REAL,
        locationCapturedAt TEXT,
        scheduledAt TEXT NOT NULL,
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        completedAt TEXT,
        FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT
      )
    ''');

    // 3. Checklist Items
    await db.execute('''
      CREATE TABLE checklist_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jobId INTEGER NOT NULL,
        label TEXT NOT NULL,
        isRequired INTEGER NOT NULL DEFAULT 1,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        result TEXT NOT NULL,
        comment TEXT,
        FOREIGN KEY (jobId) REFERENCES jobs(id) ON DELETE CASCADE
      )
    ''');

    // 4. Attachments
    await db.execute('''
      CREATE TABLE attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jobId INTEGER NOT NULL,
        checklistItemId INTEGER,
        relativePath TEXT NOT NULL,
        caption TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (jobId) REFERENCES jobs(id) ON DELETE CASCADE,
        FOREIGN KEY (checklistItemId) REFERENCES checklist_items(id) ON DELETE SET NULL
      )
    ''');

    // 5. Notes
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jobId INTEGER NOT NULL,
        text TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (jobId) REFERENCES jobs(id) ON DELETE CASCADE
      )
    ''');

    // 6. Status History
    await db.execute('''
      CREATE TABLE status_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jobId INTEGER NOT NULL,
        previousStatus TEXT,
        nextStatus TEXT NOT NULL,
        reason TEXT,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (jobId) REFERENCES jobs(id) ON DELETE CASCADE
      )
    ''');

    // 7. Sign-offs
    await db.execute('''
      CREATE TABLE sign_offs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jobId INTEGER NOT NULL,
        signerName TEXT NOT NULL,
        signatureRelativePath TEXT NOT NULL,
        signedAt TEXT NOT NULL,
        isCurrent INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (jobId) REFERENCES jobs(id) ON DELETE CASCADE
      )
    ''');

    // 8. Checklist Templates
    await db.execute('''
      CREATE TABLE templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE template_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        templateId INTEGER NOT NULL,
        label TEXT NOT NULL,
        isRequired INTEGER NOT NULL DEFAULT 1,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (templateId) REFERENCES templates(id) ON DELETE CASCADE
      )
    ''');

    // 9. App Preferences
    await db.execute('''
      CREATE TABLE app_preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration handling structure for future versions:
    // When bumping databaseVersion to 2, 3, etc., apply sequential migrations here:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE jobs ADD COLUMN estimatedDurationMinutes INTEGER');
    // }
  }

  // ==========================================
  // CUSTOMERS
  // ==========================================

  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final results = await db.query(
      'customers',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return results.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await database;
    final results = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Customer.fromMap(results.first);
  }

  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap());
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> getCustomerJobCount(int customerId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM jobs WHERE customerId = ?',
      [customerId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> deleteCustomer(int id) async {
    final jobCount = await getCustomerJobCount(id);
    if (jobCount > 0) {
      throw Exception('Cannot delete customer referenced by $jobCount job(s).');
    }
    final db = await database;
    final rowsDeleted = await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rowsDeleted > 0;
  }

  // ==========================================
  // JOBS
  // ==========================================

  Future<List<ServiceJob>> getJobs() async {
    final db = await database;
    final results = await db.query('jobs', orderBy: 'scheduledAt ASC');
    return results.map((m) => ServiceJob.fromMap(m)).toList();
  }

  Future<ServiceJob?> getJobById(int id) async {
    final db = await database;
    final results = await db.query(
      'jobs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ServiceJob.fromMap(results.first);
  }

  Future<int> insertJob(ServiceJob job) async {
    final db = await database;
    final id = await db.insert('jobs', job.toMap());

    // Record initial status in history
    await db.insert('status_history', {
      'jobId': id,
      'previousStatus': null,
      'nextStatus': job.status.name,
      'reason': 'Job created',
      'timestamp': DateTime.now().toIso8601String(),
    });

    return id;
  }

  Future<int> updateJob(ServiceJob job) async {
    final db = await database;
    return await db.update(
      'jobs',
      job.toMap(),
      where: 'id = ?',
      whereArgs: [job.id],
    );
  }

  Future<int> deleteJob(int id) async {
    final db = await database;
    return await db.delete('jobs', where: 'id = ?', whereArgs: [id]);
  }

  /// Updates job status and appends a status event atomically in one transaction
  Future<void> updateJobStatusWithTransaction({
    required int jobId,
    required JobStatus nextStatus,
    String? reason,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final currentRows = await txn.query(
        'jobs',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [jobId],
        limit: 1,
      );

      if (currentRows.isEmpty) {
        throw Exception('Job not found with id $jobId');
      }

      final prevStatusStr = currentRows.first['status'] as String;
      final prevStatus = JobStatus.fromString(prevStatusStr);
      final now = DateTime.now();

      final updateData = <String, dynamic>{
        'status': nextStatus.name,
        'updatedAt': now.toIso8601String(),
      };

      if (nextStatus == JobStatus.completed) {
        updateData['completedAt'] = now.toIso8601String();
      }

      await txn.update('jobs', updateData, where: 'id = ?', whereArgs: [jobId]);

      await txn.insert('status_history', {
        'jobId': jobId,
        'previousStatus': prevStatus.name,
        'nextStatus': nextStatus.name,
        'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
        'timestamp': now.toIso8601String(),
      });
    });
  }

  /// Reopening: marks previous sign-offs as not current, sets status to inProgress, records history
  Future<void> reopenJobWithTransaction({
    required int jobId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw Exception('A reason is required to reopen a completed job.');
    }

    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now();

      // 1. Mark existing sign-offs for this job as not current
      await txn.update(
        'sign_offs',
        {'isCurrent': 0},
        where: 'jobId = ?',
        whereArgs: [jobId],
      );

      // 2. Update job status back to inProgress and clear completedAt
      await txn.update(
        'jobs',
        {
          'status': JobStatus.inProgress.name,
          'completedAt': null,
          'updatedAt': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [jobId],
      );

      // 3. Insert status history event
      await txn.insert('status_history', {
        'jobId': jobId,
        'previousStatus': JobStatus.completed.name,
        'nextStatus': JobStatus.inProgress.name,
        'reason': reason.trim(),
        'timestamp': now.toIso8601String(),
      });
    });
  }

  // ==========================================
  // CHECKLIST ITEMS
  // ==========================================

  Future<List<ChecklistItem>> getChecklistItemsForJob(int jobId) async {
    final db = await database;
    final results = await db.query(
      'checklist_items',
      where: 'jobId = ?',
      whereArgs: [jobId],
      orderBy: 'sortOrder ASC, id ASC',
    );
    return results.map((m) => ChecklistItem.fromMap(m)).toList();
  }

  Future<int> insertChecklistItem(ChecklistItem item) async {
    final db = await database;
    return await db.insert('checklist_items', item.toMap());
  }

  Future<void> batchInsertChecklistItems(List<ChecklistItem> items) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final item in items) {
        await txn.insert('checklist_items', item.toMap());
      }
    });
  }

  Future<int> updateChecklistItem(ChecklistItem item) async {
    final db = await database;
    return await db.update(
      'checklist_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteChecklistItem(int id) async {
    final db = await database;
    return await db.delete('checklist_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderChecklistItems(int jobId, List<int> orderedIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'checklist_items',
          {'sortOrder': i},
          where: 'id = ? AND jobId = ?',
          whereArgs: [orderedIds[i], jobId],
        );
      }
    });
  }

  // ==========================================
  // ATTACHMENTS
  // ==========================================

  Future<List<Attachment>> getAttachmentsForJob(int jobId) async {
    final db = await database;
    final results = await db.query(
      'attachments',
      where: 'jobId = ?',
      whereArgs: [jobId],
      orderBy: 'createdAt DESC',
    );
    return results.map((m) => Attachment.fromMap(m)).toList();
  }

  Future<int> insertAttachment(Attachment attachment) async {
    final db = await database;
    return await db.insert('attachments', attachment.toMap());
  }

  Future<Attachment?> getAttachmentById(int id) async {
    final db = await database;
    final results = await db.query(
      'attachments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Attachment.fromMap(results.first);
  }

  Future<int> deleteAttachment(int id) async {
    final db = await database;
    return await db.delete('attachments', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // NOTES
  // ==========================================

  Future<List<JobNote>> getNotesForJob(int jobId) async {
    final db = await database;
    final results = await db.query(
      'notes',
      where: 'jobId = ?',
      whereArgs: [jobId],
      orderBy: 'createdAt DESC',
    );
    return results.map((m) => JobNote.fromMap(m)).toList();
  }

  Future<int> insertNote(JobNote note) async {
    final db = await database;
    return await db.insert('notes', note.toMap());
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // STATUS HISTORY
  // ==========================================

  Future<List<StatusEvent>> getStatusHistoryForJob(int jobId) async {
    final db = await database;
    final results = await db.query(
      'status_history',
      where: 'jobId = ?',
      whereArgs: [jobId],
      orderBy: 'timestamp DESC',
    );
    return results.map((m) => StatusEvent.fromMap(m)).toList();
  }

  Future<int> insertStatusEvent({
    required int jobId,
    String? previousStatus,
    required String nextStatus,
    String? reason,
  }) async {
    final db = await database;
    return await db.insert('status_history', {
      'jobId': jobId,
      'previousStatus': previousStatus,
      'nextStatus': nextStatus,
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ==========================================
  // SIGN-OFFS
  // ==========================================

  Future<SignOff?> getCurrentSignOffForJob(int jobId) async {
    final db = await database;
    final results = await db.query(
      'sign_offs',
      where: 'jobId = ? AND isCurrent = 1',
      whereArgs: [jobId],
      orderBy: 'signedAt DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SignOff.fromMap(results.first);
  }

  Future<List<SignOff>> getSignOffsForJob(int jobId) async {
    final db = await database;
    final results = await db.query(
      'sign_offs',
      where: 'jobId = ?',
      whereArgs: [jobId],
      orderBy: 'signedAt DESC',
    );
    return results.map((m) => SignOff.fromMap(m)).toList();
  }

  Future<int> insertSignOff(SignOff signOff) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Invalidate any existing current sign-offs
      await txn.update(
        'sign_offs',
        {'isCurrent': 0},
        where: 'jobId = ?',
        whereArgs: [signOff.jobId],
      );

      return await txn.insert('sign_offs', signOff.toMap());
    });
  }

  // ==========================================
  // CHECKLIST TEMPLATES
  // ==========================================

  Future<List<ChecklistTemplate>> getTemplates() async {
    final db = await database;
    final templateRows = await db.query('templates', orderBy: 'name ASC');

    final List<ChecklistTemplate> templates = [];
    for (final row in templateRows) {
      final templateId = row['id'] as int;
      final itemRows = await db.query(
        'template_items',
        where: 'templateId = ?',
        whereArgs: [templateId],
        orderBy: 'sortOrder ASC',
      );
      final items = itemRows.map((m) => TemplateItem.fromMap(m)).toList();
      templates.add(ChecklistTemplate.fromMap(row, items: items));
    }
    return templates;
  }

  Future<int> insertTemplate(
    ChecklistTemplate template,
    List<TemplateItem> items,
  ) async {
    final db = await database;
    return await db.transaction((txn) async {
      final templateId = await txn.insert('templates', template.toMap());
      for (int i = 0; i < items.length; i++) {
        final item = items[i].copyWith(templateId: templateId, sortOrder: i);
        await txn.insert('template_items', item.toMap());
      }
      return templateId;
    });
  }

  Future<void> updateTemplate(
    ChecklistTemplate template,
    List<TemplateItem> items,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'templates',
        template.toMap(),
        where: 'id = ?',
        whereArgs: [template.id],
      );

      // Re-create items for this template without altering already copied items in jobs
      await txn.delete(
        'template_items',
        where: 'templateId = ?',
        whereArgs: [template.id],
      );

      for (int i = 0; i < items.length; i++) {
        final item = items[i].copyWith(templateId: template.id, sortOrder: i);
        await txn.insert('template_items', item.toMap());
      }
    });
  }

  Future<int> deleteTemplate(int id) async {
    final db = await database;
    return await db.delete('templates', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // PREFERENCES
  // ==========================================

  Future<String?> getPreference(String key) async {
    final db = await database;
    final results = await db.query(
      'app_preferences',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  Future<void> setPreference(String key, String value) async {
    final db = await database;
    await db.insert(
        'app_preferences',
        {
          'key': key,
          'value': value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ==========================================
  // RESET / CLEAR
  // ==========================================

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sign_offs');
      await txn.delete('status_history');
      await txn.delete('notes');
      await txn.delete('attachments');
      await txn.delete('checklist_items');
      await txn.delete('jobs');
      await txn.delete('template_items');
      await txn.delete('templates');
      await txn.delete('customers');
      await txn.delete('app_preferences');
    });
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
