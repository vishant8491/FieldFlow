import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fieldflow/models/attachment.dart';
import 'package:fieldflow/models/checklist_item.dart';
import 'package:fieldflow/models/checklist_template.dart';
import 'package:fieldflow/models/customer.dart';
import 'package:fieldflow/models/job_note.dart';
import 'package:fieldflow/models/service_job.dart';
import 'package:fieldflow/models/sign_off.dart';
import 'package:fieldflow/models/template_item.dart';
import 'package:fieldflow/providers/jobs_provider.dart';
import 'package:fieldflow/services/attachment_service.dart';
import 'package:fieldflow/services/database_service.dart';
import 'package:fieldflow/services/pdf_service.dart';

void main() {
  final testDir = p.join(Directory.current.path, 'test_integration_env');
  final testDbPath = p.join(testDir, 'integration_test.db');
  final testDocsDir = p.join(testDir, 'app_docs');

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = Directory(testDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);

    DatabaseService.overrideDatabasePath = testDbPath;
    AttachmentService.overrideAppDocDir = testDocsDir;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
    DatabaseService.overrideDatabasePath = null;
    AttachmentService.overrideAppDocDir = null;

    final dir = Directory(testDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test(
    'Complete End-to-End User Journey: Customer -> Draft -> Schedule -> Start -> Checklist -> Photo -> Sign -> Complete -> PDF -> Reopen DB -> Reopen Job -> Blocked Re-completion',
    () async {
      final db = DatabaseService.instance;
      final attachService = AttachmentService.instance;
      final pdfService = PdfService.instance;

      // 1. Create Customer
      final customer = Customer(
        name: 'Apex Industrial Robotics Inc.',
        phone: '+1 555-0812',
        email: 'ops@apexrobotics.test',
      );
      final customerId = await db.insertCustomer(customer);
      expect(customerId, greaterThan(0));

      final savedCustomer = await db.getCustomerById(customerId);
      expect(savedCustomer, isNotNull);
      expect(savedCustomer!.name, 'Apex Industrial Robotics Inc.');

      // 2. Create Draft Job (address and customer can be incomplete initially)
      final now = DateTime.now();
      final draftJob = ServiceJob(
        title: 'Diagnostic Audit on Assembly Line Robot #4',
        description:
            'Technician dispatched to assess abnormal vibration on servo motor 2.',
        customerId: customerId,
        address: '', // Incomplete draft address
        scheduledAt: now.add(const Duration(hours: 4)),
        status: JobStatus.draft,
        priority: JobPriority.high,
        createdAt: now,
        updatedAt: now,
      );
      final jobId = await db.insertJob(draftJob);
      expect(jobId, greaterThan(0));

      var currentJob = (await db.getJobById(jobId))!;
      expect(currentJob.status, JobStatus.draft);

      // Verify draft cannot be completed
      final provider = JobsProvider();
      await provider.initialize();

      expect(
        () => provider.transitionJobStatus(
          jobId: jobId,
          nextStatus: JobStatus.completed,
        ),
        throwsA(isA<Exception>()),
      );

      // 3. Schedule the Job (Requires valid customer, address, and schedule)
      final scheduledJob = currentJob.copyWith(
        address: '450 Technology Parkway, Suite 100',
        status: JobStatus.scheduled,
        updatedAt: DateTime.now(),
      );
      await db.updateJob(scheduledJob);

      await db.updateJobStatusWithTransaction(
        jobId: jobId,
        nextStatus: JobStatus.scheduled,
        reason: 'Customer confirmed service window',
      );

      currentJob = (await db.getJobById(jobId))!;
      expect(currentJob.status, JobStatus.scheduled);
      expect(currentJob.address, '450 Technology Parkway, Suite 100');

      // 4. Start the Job (Transitions to inProgress)
      await db.updateJobStatusWithTransaction(
        jobId: jobId,
        nextStatus: JobStatus.inProgress,
        reason: 'Technician arrived on-site',
      );

      currentJob = (await db.getJobById(jobId))!;
      expect(currentJob.status, JobStatus.inProgress);

      // 5. Apply Inspection Template to Job
      final template = ChecklistTemplate(
        name: 'Robotics Preventative Maintenance',
        description: 'Standard 4-point robotic arm inspection',
        createdAt: now,
        items: [
          TemplateItem(
            templateId: 0,
            label: 'Verify harmonic drive lubrication and oil seals',
            isRequired: true,
            sortOrder: 0,
          ),
          TemplateItem(
            templateId: 0,
            label: 'Test emergency stop circuit and dead-man switch',
            isRequired: true,
            sortOrder: 1,
          ),
          TemplateItem(
            templateId: 0,
            label: 'Inspect pneumatic line pressure and air filter regulator',
            isRequired: true,
            sortOrder: 2,
          ),
          TemplateItem(
            templateId: 0,
            label: 'Secondary axis backup battery level check',
            isRequired: false,
            sortOrder: 3,
          ),
        ],
      );

      await provider.applyTemplateToJob(jobId: jobId, template: template);

      var checklist = await db.getChecklistItemsForJob(jobId);
      expect(checklist.length, 4);
      expect(checklist[0].label, contains('harmonic drive lubrication'));
      expect(checklist[0].result, ChecklistResult.pending);

      // 6. Test Checklist Reordering and verify persistence
      final originalIds = checklist.map((e) => e.id!).toList();
      final reversedIds = originalIds.reversed.toList();
      await db.reorderChecklistItems(jobId, reversedIds);

      var reorderedChecklist = await db.getChecklistItemsForJob(jobId);
      expect(reorderedChecklist.first.id, reversedIds.first);
      expect(reorderedChecklist.last.id, reversedIds.last);

      // Restore original order for consistent evaluation
      await db.reorderChecklistItems(jobId, originalIds);
      checklist = await db.getChecklistItemsForJob(jobId);

      // Verify completion blockers block premature completion
      var blockers = provider.getCompletionBlockers(
        job: currentJob,
        checklist: checklist,
        currentSignOff: null,
      );
      expect(blockers.isNotEmpty, isTrue);
      expect(blockers.any((b) => b.contains('pending')), isTrue);
      expect(blockers.any((b) => b.contains('sign-off')), isTrue);

      // 7. Record Checklist Results & Comments
      // Item 0: Pass
      await db.updateChecklistItem(
        checklist[0].copyWith(
          result: ChecklistResult.pass,
          comment: 'Lubrication levels nominal, no seal weeping detected.',
        ),
      );

      // Item 1: Fail with mandatory explanatory comment
      await db.updateChecklistItem(
        checklist[1].copyWith(
          result: ChecklistResult.fail,
          comment:
              'E-stop button 2 has sticky reset contact; replaced contact block.',
        ),
      );

      // Item 2: Not Applicable on required item with required justification
      await db.updateChecklistItem(
        checklist[2].copyWith(
          result: ChecklistResult.notApplicable,
          comment:
              'Robot #4 uses pure electric servo actuators; no pneumatics.',
        ),
      );

      // Item 3: Optional item left as Pass
      await db.updateChecklistItem(
        checklist[3].copyWith(
          result: ChecklistResult.pass,
          comment: 'Battery voltage 3.65V (good).',
        ),
      );

      checklist = await db.getChecklistItemsForJob(jobId);
      expect(checklist.every((i) => i.isAssessed), isTrue);

      // 8. Add Field Note & Photo Evidence
      await db.insertNote(
        JobNote(
          jobId: jobId,
          text:
              'Completed servo motor calibration and tested cycle for 15 minutes at full payload.',
          createdAt: DateTime.now(),
        ),
      );

      // Simulate saving an attachment
      final fakePngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);

      final photoRelPath = await attachService.saveSignatureBytes(
        bytes: fakePngBytes,
        jobId: jobId,
      );
      final attachmentId = await db.insertAttachment(
        Attachment(
          jobId: jobId,
          relativePath: photoRelPath,
          caption: 'Replacement E-stop contact block installed',
          createdAt: DateTime.now(),
        ),
      );
      expect(attachmentId, greaterThan(0));

      // Check blockers still block completion because sign-off is missing
      blockers = provider.getCompletionBlockers(
        job: currentJob,
        checklist: checklist,
        currentSignOff: null,
      );
      expect(blockers.length, 1);
      expect(blockers.first, contains('sign-off'));

      // 9. Record Customer Sign-Off
      final sigRelPath = await attachService.saveSignatureBytes(
        bytes: fakePngBytes,
        jobId: jobId,
      );
      final signOff = SignOff(
        jobId: jobId,
        signerName: 'Marcus Vance, Plant Operations Lead',
        signatureRelativePath: sigRelPath,
        signedAt: DateTime.now(),
        isCurrent: true,
      );
      final signOffId = await db.insertSignOff(signOff);
      expect(signOffId, greaterThan(0));

      final currentSignOff = await db.getCurrentSignOffForJob(jobId);
      expect(currentSignOff, isNotNull);
      expect(currentSignOff!.isCurrent, isTrue);
      expect(
        currentSignOff.signerName,
        'Marcus Vance, Plant Operations Lead',
      );

      // Verify no blockers remain
      blockers = provider.getCompletionBlockers(
        job: currentJob,
        checklist: checklist,
        currentSignOff: currentSignOff,
      );
      expect(blockers.isEmpty, isTrue);

      // 10. Complete the Job
      await db.updateJobStatusWithTransaction(
        jobId: jobId,
        nextStatus: JobStatus.completed,
        reason: 'All checks passed and customer signed off',
      );

      currentJob = (await db.getJobById(jobId))!;
      expect(currentJob.status, JobStatus.completed);
      expect(currentJob.completedAt, isNotNull);
      expect(currentJob.isReadOnly, isTrue);

      // 11. Generate PDF Report
      final attachments = await db.getAttachmentsForJob(jobId);
      final notes = await db.getNotesForJob(jobId);
      final statusHistory = await db.getStatusHistoryForJob(jobId);

      final pdfBytes = await pdfService.generateReportPdf(
        job: currentJob,
        customer: savedCustomer,
        checklistItems: checklist,
        attachments: attachments,
        notes: notes,
        statusHistory: statusHistory,
        signOff: currentSignOff,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, '%PDF-');

      // 12. Reopen Database and Verify All Records Persisted
      await db.close();

      final reloadedJob = await db.getJobById(jobId);
      expect(reloadedJob, isNotNull);
      expect(reloadedJob!.status, JobStatus.completed);
      expect(reloadedJob.completedAt, isNotNull);

      final reloadedChecklist = await db.getChecklistItemsForJob(jobId);
      expect(reloadedChecklist.length, 4);
      expect(reloadedChecklist[0].result, ChecklistResult.pass);
      expect(reloadedChecklist[1].result, ChecklistResult.fail);
      expect(reloadedChecklist[2].result, ChecklistResult.notApplicable);

      final reloadedSignOff = await db.getCurrentSignOffForJob(jobId);
      expect(reloadedSignOff, isNotNull);
      expect(reloadedSignOff!.isCurrent, isTrue);

      // 13. Reopen Job (Requires a reason, clears completedAt, invalidates sign-off)
      await db.reopenJobWithTransaction(
        jobId: jobId,
        reason: 'Customer reported unexpected sensor drift on axis 3',
      );

      final reopenedJob = (await db.getJobById(jobId))!;
      expect(reopenedJob.status, JobStatus.inProgress);
      expect(reopenedJob.completedAt, isNull);
      expect(reopenedJob.isReadOnly, isFalse);

      // Verify previous sign-off is no longer current
      final activeSignOffAfterReopen = await db.getCurrentSignOffForJob(jobId);
      expect(activeSignOffAfterReopen, isNull);

      final allSignOffs = await db.getSignOffsForJob(jobId);
      expect(allSignOffs.length, 1);
      expect(allSignOffs.first.isCurrent, isFalse);

      // Verify completion is strictly BLOCKED until fresh signature is captured
      final blockersAfterReopen = provider.getCompletionBlockers(
        job: reopenedJob,
        checklist: reloadedChecklist,
        currentSignOff: activeSignOffAfterReopen,
      );
      expect(blockersAfterReopen.isNotEmpty, isTrue);
      expect(
        blockersAfterReopen.any((b) => b.contains('sign-off and signature')),
        isTrue,
      );
    },
  );
}
