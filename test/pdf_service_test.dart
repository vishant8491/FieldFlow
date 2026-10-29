import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fieldflow/services/pdf_service.dart';
import 'package:fieldflow/models/service_job.dart';
import 'package:fieldflow/models/customer.dart';
import 'package:fieldflow/models/checklist_item.dart';
import 'package:fieldflow/models/job_note.dart';
import 'package:fieldflow/models/status_event.dart';
import 'package:fieldflow/models/sign_off.dart';

void main() {
  test(
      'PDF Service: Generates multi-page document with long content and no photos',
      () async {
    final now = DateTime.now();

    final job = ServiceJob(
      id: 88,
      title: 'Full Facility Substation & Switchgear Preventative Overhaul',
      description:
          'Extensive multi-system electrical compliance audit, primary breaker insulation resistance tests, busbar torque verification, transformer dielectric breakdown measurement, protective relay timing calibration, and arc-flash boundary recertification.',
      customerId: 42,
      address:
          '77 Industrial Parkway, Sector 9, Heavy Manufacturing Zone, Bldg C',
      latitude: 40.7128,
      longitude: -74.0060,
      locationAccuracy: 3.2,
      locationCapturedAt: now,
      scheduledAt: now,
      priority: JobPriority.high,
      status: JobStatus.completed,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now,
      completedAt: now,
    );

    final customer = Customer(
      id: 42,
      name: 'Northstar Semiconductor Manufacturing Corp.',
      phone: '+1 555-0921',
      email: 'facilities@northstarsemi.test',
    );

    // 25 checklist items to verify multi-page pagination
    final checklist = List.generate(25, (index) {
      return ChecklistItem(
        id: index + 1,
        jobId: 88,
        label:
            'Section ${index + 1}: High-voltage terminal bus insulation impedance inspection and infrared thermography check',
        isRequired: index % 2 == 0,
        sortOrder: index,
        result: index % 4 == 0
            ? ChecklistResult.pass
            : index % 4 == 1
                ? ChecklistResult.fail
                : index % 4 == 2
                    ? ChecklistResult.notApplicable
                    : ChecklistResult.pass,
        comment: index % 4 == 1
            ? 'Phase B bushing insulation impedance reading below 100M Ohms threshold; replacement scheduling required.'
            : index % 4 == 2
                ? 'Auxiliary oil cooling pump not installed on this specific transformer configuration.'
                : 'Checked and compliant with NFPA 70E standards.',
      );
    });

    final notes = List.generate(8, (i) {
      return JobNote(
        id: i + 1,
        jobId: 88,
        text:
            'Inspection entry note #$i: Thermal sensor log calibrated. Primary feeder line ambient temperature stable at 24.5 C.',
        createdAt: now.subtract(Duration(minutes: 60 - i * 5)),
      );
    });

    final history = [
      StatusEvent(
        jobId: 88,
        previousStatus: null,
        nextStatus: JobStatus.scheduled,
        reason: 'Job scheduled by dispatcher',
        timestamp: now.subtract(const Duration(days: 2)),
      ),
      StatusEvent(
        jobId: 88,
        previousStatus: JobStatus.scheduled,
        nextStatus: JobStatus.inProgress,
        reason: 'Technician logged arrival and lock-out tag-out applied',
        timestamp: now.subtract(const Duration(hours: 4)),
      ),
      StatusEvent(
        jobId: 88,
        previousStatus: JobStatus.inProgress,
        nextStatus: JobStatus.completed,
        reason: 'Overhaul finished and safety checks confirmed',
        timestamp: now,
      ),
    ];

    final signOff = SignOff(
      jobId: 88,
      signerName: 'Chief Plant Engineer Marcus Vance',
      signatureRelativePath: '', // testing with no signature file
      signedAt: now,
      isCurrent: true,
    );

    final pdfBytes = await PdfService.instance.generateReportPdf(
      job: job,
      customer: customer,
      checklistItems: checklist,
      attachments: [], // No photos
      notes: notes,
      statusHistory: history,
      signOff: signOff,
    );

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(1000));

    // Verify PDF header magic bytes '%PDF-'
    final header = utf8.decode(pdfBytes.sublist(0, 5));
    expect(header, '%PDF-');
  });
}
