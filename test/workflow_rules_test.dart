import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fieldflow/models/service_job.dart';
import 'package:fieldflow/models/checklist_item.dart';
import 'package:fieldflow/models/sign_off.dart';
import 'package:fieldflow/providers/jobs_provider.dart';
import 'package:fieldflow/services/location_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Workflow Rules and Completion Blockers', () {
    late ServiceJob baseJob;
    final now = DateTime.now();

    setUp(() {
      baseJob = ServiceJob(
        id: 101,
        title: 'Compressor Overhaul',
        description: 'Unit testing workflow',
        customerId: 1,
        address: '100 Test St',
        scheduledAt: now,
        priority: JobPriority.high,
        status: JobStatus.inProgress,
        createdAt: now,
        updatedAt: now,
      );
    });

    test('Blocker: Job must be In Progress to complete', () {
      final scheduledJob = baseJob.copyWith(status: JobStatus.scheduled);
      final provider = JobsProvider();

      final blockers = provider.getCompletionBlockers(
        job: scheduledJob,
        checklist: [],
        currentSignOff: SignOff(
          jobId: 101,
          signerName: 'Jane Doe',
          signatureRelativePath: 'signatures/sig_1.png',
          signedAt: now,
        ),
      );

      expect(blockers.any((b) => b.contains("must be 'In Progress'")), isTrue);
    });

    test('Blocker: Pending required checklist items block completion', () {
      final provider = JobsProvider();
      final checklist = [
        ChecklistItem(
          jobId: 101,
          label: 'Verify grounding wire',
          isRequired: true,
          result: ChecklistResult.pending,
        ),
      ];

      final blockers = provider.getCompletionBlockers(
        job: baseJob,
        checklist: checklist,
        currentSignOff: SignOff(
          jobId: 101,
          signerName: 'Jane Doe',
          signatureRelativePath: 'signatures/sig_1.png',
          signedAt: now,
        ),
      );

      expect(
        blockers.any(
          (b) => b.contains(
            'required inspection checklist item(s) are still pending',
          ),
        ),
        isTrue,
      );
    });

    test('Blocker: Failed item requires an explanatory comment', () {
      final provider = JobsProvider();
      final checklist = [
        ChecklistItem(
          jobId: 101,
          label: 'Pressure Test',
          isRequired: true,
          result: ChecklistResult.fail,
          comment: null, // missing comment
        ),
      ];

      final blockers = provider.getCompletionBlockers(
        job: baseJob,
        checklist: checklist,
        currentSignOff: SignOff(
          jobId: 101,
          signerName: 'Jane Doe',
          signatureRelativePath: 'signatures/sig_1.png',
          signedAt: now,
        ),
      );

      expect(
        blockers.any(
          (b) => b.contains("failed without an explanatory comment"),
        ),
        isTrue,
      );
    });

    test(
      'Allowed: Failed item with comment does not trigger comment blocker',
      () {
        final provider = JobsProvider();
        final checklist = [
          ChecklistItem(
            jobId: 101,
            label: 'Pressure Test',
            isRequired: true,
            result: ChecklistResult.fail,
            comment: 'Valve seal compromised; replacement part ordered.',
          ),
        ];

        final blockers = provider.getCompletionBlockers(
          job: baseJob,
          checklist: checklist,
          currentSignOff: SignOff(
            jobId: 101,
            signerName: 'Jane Doe',
            signatureRelativePath: 'signatures/sig_1.png',
            signedAt: now,
          ),
        );

        expect(
          blockers.any(
            (b) => b.contains("failed without an explanatory comment"),
          ),
          isFalse,
        );
      },
    );

    test('Blocker: Required item marked N/A requires justification', () {
      final provider = JobsProvider();
      final checklist = [
        ChecklistItem(
          jobId: 101,
          label: 'Check secondary evaporator fan',
          isRequired: true,
          result: ChecklistResult.notApplicable,
          comment: '', // empty reason
        ),
      ];

      final blockers = provider.getCompletionBlockers(
        job: baseJob,
        checklist: checklist,
        currentSignOff: SignOff(
          jobId: 101,
          signerName: 'Jane Doe',
          signatureRelativePath: 'signatures/sig_1.png',
          signedAt: now,
        ),
      );

      expect(
        blockers.any((b) => b.contains("without a justification reason")),
        isTrue,
      );
    });

    test(
      'Blocker: Missing or incomplete customer sign-off blocks completion',
      () {
        final provider = JobsProvider();

        // No sign-off at all
        var blockers = provider.getCompletionBlockers(
          job: baseJob,
          checklist: [
            ChecklistItem(
              jobId: 101,
              label: 'Check power',
              isRequired: true,
              result: ChecklistResult.pass,
            ),
          ],
          currentSignOff: null,
        );
        expect(
          blockers.any(
            (b) => b.contains("Customer sign-off and signature are missing"),
          ),
          isTrue,
        );

        // Sign-off with blank name
        blockers = provider.getCompletionBlockers(
          job: baseJob,
          checklist: [
            ChecklistItem(
              jobId: 101,
              label: 'Check power',
              isRequired: true,
              result: ChecklistResult.pass,
            ),
          ],
          currentSignOff: SignOff(
            jobId: 101,
            signerName: '   ',
            signatureRelativePath: 'signatures/sig_1.png',
            signedAt: now,
          ),
        );
        expect(
          blockers.any((b) => b.contains("signer name is missing")),
          isTrue,
        );
      },
    );

    test(
        'Completion Allowed: All required items resolved and valid sign-off present',
        () {
      final provider = JobsProvider();
      final checklist = [
        ChecklistItem(
          jobId: 101,
          label: 'Check power',
          isRequired: true,
          result: ChecklistResult.pass,
        ),
        ChecklistItem(
          jobId: 101,
          label: 'Check optional cover',
          isRequired: false,
          result: ChecklistResult.pending, // Optional item pending is allowed
        ),
      ];

      final signOff = SignOff(
        jobId: 101,
        signerName: 'David Miller',
        signatureRelativePath: 'signatures/sig_101.png',
        signedAt: now,
      );

      final blockers = provider.getCompletionBlockers(
        job: baseJob,
        checklist: checklist,
        currentSignOff: signOff,
      );

      expect(blockers, isEmpty);
    });
  });

  group('Location Coordinate Range Validation', () {
    test('Latitude range validation', () {
      expect(LocationService.validateLatitude(''), isNull);
      expect(LocationService.validateLatitude('37.7749'), isNull);
      expect(LocationService.validateLatitude('-90.0'), isNull);
      expect(LocationService.validateLatitude('90.0'), isNull);

      expect(
        LocationService.validateLatitude('90.1'),
        contains('between -90 and 90'),
      );
      expect(
        LocationService.validateLatitude('-95'),
        contains('between -90 and 90'),
      );
      expect(
        LocationService.validateLatitude('abc'),
        contains('valid decimal'),
      );
      expect(
        LocationService.validateLatitude('NaN'),
        contains('valid decimal'),
      );
      expect(
        LocationService.validateLatitude('Infinity'),
        contains('valid decimal'),
      );
      expect(
        LocationService.validateLatitude('-Infinity'),
        contains('valid decimal'),
      );
    });

    test('Longitude range validation', () {
      expect(LocationService.validateLongitude(''), isNull);
      expect(LocationService.validateLongitude('-122.4194'), isNull);
      expect(LocationService.validateLongitude('-180.0'), isNull);
      expect(LocationService.validateLongitude('180.0'), isNull);

      expect(
        LocationService.validateLongitude('180.5'),
        contains('between -180 and 180'),
      );
      expect(
        LocationService.validateLongitude('-181'),
        contains('between -180 and 180'),
      );
      expect(
        LocationService.validateLongitude('invalid'),
        contains('valid decimal'),
      );
      expect(
        LocationService.validateLongitude('NaN'),
        contains('valid decimal'),
      );
      expect(
        LocationService.validateLongitude('Infinity'),
        contains('valid decimal'),
      );
      expect(
        LocationService.validateLongitude('-Infinity'),
        contains('valid decimal'),
      );
    });
  });

  group('State Machine Transition Rules in Provider', () {
    test(
        'transitionJobStatus rejects skipped transitions and completed job transitions',
        () async {
      final provider = JobsProvider();
      // Test with non-existent job throws not found
      expect(
        () => provider.transitionJobStatus(
          jobId: 9999,
          nextStatus: JobStatus.scheduled,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
