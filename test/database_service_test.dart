import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fieldflow/services/database_service.dart';
import 'package:fieldflow/models/customer.dart';
import 'package:fieldflow/models/service_job.dart';
import 'package:fieldflow/models/sign_off.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.overrideDatabasePath = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
    DatabaseService.overrideDatabasePath = null;
  });

  group('DatabaseService SQLite Integration Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.clearAllData();
    });

    test('Customer CRUD and Job Foreign Key Restriction', () async {
      final customerId = await dbService.insertCustomer(
        Customer(
          name: 'Test Customer Hub',
          phone: '+1 555-9999',
          email: 'test@customer.org',
        ),
      );
      expect(customerId, greaterThan(0));

      final fetched = await dbService.getCustomerById(customerId);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Test Customer Hub');

      // Create a job referencing this customer
      final now = DateTime.now();
      final jobId = await dbService.insertJob(
        ServiceJob(
          title: 'Network Setup',
          description: 'Test job',
          customerId: customerId,
          address: '123 Main St',
          scheduledAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(jobId, greaterThan(0));

      // Attempting to delete customer should throw because of job count restriction
      expect(
        () async => await dbService.deleteCustomer(customerId),
        throwsA(isA<Exception>()),
      );

      // Delete job first
      await dbService.deleteJob(jobId);

      // Now customer can be deleted safely
      final deleted = await dbService.deleteCustomer(customerId);
      expect(deleted, isTrue);
    });

    test('Atomic Status Transition and Status History Transaction', () async {
      final now = DateTime.now();
      final custId = await dbService.insertCustomer(
        Customer(name: 'Acme Logistics', phone: '555-1234'),
      );

      final jobId = await dbService.insertJob(
        ServiceJob(
          title: 'Emergency Generator Maintenance',
          description: 'Perform 100hr service',
          customerId: custId,
          address: '45 Dock Road',
          scheduledAt: now,
          status: JobStatus.scheduled,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Transition to In Progress
      await dbService.updateJobStatusWithTransaction(
        jobId: jobId,
        nextStatus: JobStatus.inProgress,
        reason: 'Technician on site',
      );

      final job = await dbService.getJobById(jobId);
      expect(job!.status, JobStatus.inProgress);

      final history = await dbService.getStatusHistoryForJob(jobId);
      expect(history.length, greaterThanOrEqualTo(2));
      expect(history.first.nextStatus, JobStatus.inProgress);
      expect(history.first.reason, 'Technician on site');
    });

    test(
        'Reopening Completed Job: Invalidates previous sign-off & requires new one',
        () async {
      final now = DateTime.now();
      final custId = await dbService.insertCustomer(
        Customer(name: 'Metro Hospitals', phone: '555-8888'),
      );

      final jobId = await dbService.insertJob(
        ServiceJob(
          title: 'Sterilizer Validation',
          description: 'Autoclave temperature mapping',
          customerId: custId,
          address: '99 Hospital Way',
          scheduledAt: now,
          status: JobStatus.inProgress,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Insert customer sign-off
      await dbService.insertSignOff(
        SignOff(
          jobId: jobId,
          signerName: 'Nurse Supervisor',
          signatureRelativePath: 'signatures/sig_test.png',
          signedAt: now,
          isCurrent: true,
        ),
      );

      var currentSignOff = await dbService.getCurrentSignOffForJob(jobId);
      expect(currentSignOff, isNotNull);
      expect(currentSignOff!.isCurrent, isTrue);

      // Complete job
      await dbService.updateJobStatusWithTransaction(
        jobId: jobId,
        nextStatus: JobStatus.completed,
        reason: 'Validation tests passed',
      );

      var completedJob = await dbService.getJobById(jobId);
      expect(completedJob!.status, JobStatus.completed);
      expect(completedJob.completedAt, isNotNull);

      // Explicitly reopen job with reason
      await dbService.reopenJobWithTransaction(
        jobId: jobId,
        reason: 'Client reported intermittent pressure alert after reboot',
      );

      final reopenedJob = await dbService.getJobById(jobId);
      expect(reopenedJob!.status, JobStatus.inProgress);
      expect(reopenedJob.completedAt, isNull);

      // Previous sign-off must now be marked NOT current
      currentSignOff = await dbService.getCurrentSignOffForJob(jobId);
      expect(currentSignOff, isNull);

      // All sign-offs history is still preserved
      final allSignOffs = await dbService.getSignOffsForJob(jobId);
      expect(allSignOffs.length, 1);
      expect(allSignOffs.first.isCurrent, isFalse);

      // Reopening reason recorded in history
      final history = await dbService.getStatusHistoryForJob(jobId);
      expect(history.first.previousStatus, JobStatus.completed);
      expect(history.first.nextStatus, JobStatus.inProgress);
      expect(history.first.reason, contains('intermittent pressure alert'));
    });
  });
}
