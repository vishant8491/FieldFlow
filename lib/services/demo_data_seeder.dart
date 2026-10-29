import 'package:flutter/material.dart';

import 'dart:ui' as ui;

import '../models/customer.dart';
import '../models/service_job.dart';
import '../models/checklist_item.dart';
import '../models/checklist_template.dart';
import '../models/template_item.dart';
import '../models/job_note.dart';
import '../models/sign_off.dart';
import 'database_service.dart';
import 'attachment_service.dart';

class DemoDataSeeder {
  static Future<void> seedTemplates(DatabaseService db) async {
    // 1. Appliance Maintenance
    await db.insertTemplate(
      ChecklistTemplate(
        name: 'Appliance Maintenance',
        description:
            'Standard quarterly maintenance for commercial & domestic equipment.',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      [
        TemplateItem(
          templateId: 0,
          label: 'Inspect power cord, grounding, and electrical connections',
          isRequired: true,
          sortOrder: 0,
        ),
        TemplateItem(
          templateId: 0,
          label: 'Check operating temperatures and thermostat accuracy',
          isRequired: true,
          sortOrder: 1,
        ),
        TemplateItem(
          templateId: 0,
          label: 'Clean condenser coils, fan blades, and ventilation ducts',
          isRequired: true,
          sortOrder: 2,
        ),
        TemplateItem(
          templateId: 0,
          label: 'Inspect door gaskets and seals for wear or leaks',
          isRequired: false,
          sortOrder: 3,
        ),
        TemplateItem(
          templateId: 0,
          label: 'Verify safety emergency shutoff mechanism',
          isRequired: true,
          sortOrder: 4,
        ),
      ],
    );

    // 2. Office Safety Inspection
    await db.insertTemplate(
      ChecklistTemplate(
        name: 'Office Safety Inspection',
        description:
            'Routine workplace health, hazard, and fire code safety review.',
        createdAt: DateTime.now().subtract(const Duration(days: 9)),
      ),
      [
        TemplateItem(
          templateId: 0,
          label:
              'Verify emergency exit pathways and illuminated signs are unobstructed',
          isRequired: true,
          sortOrder: 0,
        ),
        TemplateItem(
          templateId: 0,
          label:
              'Check fire extinguisher pressure gauge and annual inspection tag',
          isRequired: true,
          sortOrder: 1,
        ),
        TemplateItem(
          templateId: 0,
          label: 'Test emergency lighting battery backup systems',
          isRequired: true,
          sortOrder: 2,
        ),
        TemplateItem(
          templateId: 0,
          label: 'Verify first aid medical kits are stocked and sealed',
          isRequired: false,
          sortOrder: 3,
        ),
        TemplateItem(
          templateId: 0,
          label: 'Inspect electrical panel clear clearance (min 36 inches)',
          isRequired: true,
          sortOrder: 4,
        ),
      ],
    );

    // 3. Network Installation
    await db.insertTemplate(
      ChecklistTemplate(
        name: 'Network Installation',
        description:
            'Structured cabling and networking hardware commissioning checklist.',
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
      [
        TemplateItem(
          templateId: 0,
          label: 'Verify network rack mounting and equipment grounding',
          isRequired: true,
          sortOrder: 0,
        ),
        TemplateItem(
          templateId: 0,
          label: 'Test Cat6 cable continuity and wire map on all drops',
          isRequired: true,
          sortOrder: 1,
        ),
        TemplateItem(
          templateId: 0,
          label: 'Label patch panels, wall plates, and switch ports',
          isRequired: true,
          sortOrder: 2,
        ),
        TemplateItem(
          templateId: 0,
          label: 'Verify uplink connection and measure ping/latency to gateway',
          isRequired: true,
          sortOrder: 3,
        ),
        TemplateItem(
          templateId: 0,
          label: 'Bundle and secure cabling with hook-and-loop ties',
          isRequired: false,
          sortOrder: 4,
        ),
      ],
    );
  }

  static Future<void> seedDemoWorkspace({
    required DatabaseService db,
    required AttachmentService attachmentService,
  }) async {
    final now = DateTime.now();

    // 1. Templates
    await seedTemplates(db);

    // 2. Synthetic Customers
    final c1Id = await db.insertCustomer(
      Customer(
        name: 'Apex Retail Solutions',
        phone: '+1 555-0142',
        email: 'service@apexretail.test',
      ),
    );

    final c2Id = await db.insertCustomer(
      Customer(
        name: 'Harborview Logistics Hub',
        phone: '+1 555-0198',
        email: 'facility@harborview.test',
      ),
    );

    final c3Id = await db.insertCustomer(
      Customer(
        name: 'Dr. Elena Rostova Clinic',
        phone: '+1 555-0114',
        email: 'admin@rostovaclinic.test',
      ),
    );

    final c4Id = await db.insertCustomer(
      Customer(
        name: 'Blue Horizon Coffee Co.',
        phone: '+1 555-0177',
        email: 'manager@bluehorizon.test',
      ),
    );

    // Generate a simple synthetic signature image
    String demoSignaturePath = '';
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 300, 100));
      final paint = Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(30, 60);
      path.quadraticBezierTo(70, 20, 110, 55);
      path.quadraticBezierTo(150, 85, 190, 40);
      path.quadraticBezierTo(230, 20, 270, 50);
      canvas.drawPath(path, paint);

      final picture = recorder.endRecording();
      final img = await picture.toImage(300, 100);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        demoSignaturePath = await attachmentService.saveSignatureBytes(
          bytes: bytes,
          jobId: 1,
        );
      }
    } catch (_) {}

    // Job 1: Completed Job
    final job1Id = await db.insertJob(
      ServiceJob(
        title: 'Commercial Refrigerator Quarterly PM',
        description:
            'Scheduled preventive maintenance on walk-in freezer & compressor units.',
        customerId: c1Id,
        address: '742 Evergreen Terrace, Suite 100, Springfield',
        latitude: 37.7749,
        longitude: -122.4194,
        locationAccuracy: 4.8,
        locationCapturedAt: now.subtract(const Duration(days: 1, hours: 3)),
        scheduledAt: now.subtract(const Duration(days: 1, hours: 4)),
        priority: JobPriority.high,
        status: JobStatus.completed,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 1)),
        completedAt: now.subtract(const Duration(days: 1)),
      ),
    );

    await db.batchInsertChecklistItems([
      ChecklistItem(
        jobId: job1Id,
        label: 'Inspect power cord, grounding, and electrical connections',
        isRequired: true,
        sortOrder: 0,
        result: ChecklistResult.pass,
        comment: 'All terminal connections tight and properly grounded.',
      ),
      ChecklistItem(
        jobId: job1Id,
        label: 'Check operating temperatures and thermostat accuracy',
        isRequired: true,
        sortOrder: 1,
        result: ChecklistResult.pass,
        comment:
            'Freezer holding at -2.5°C. Digital sensor matched calibrated gauge.',
      ),
      ChecklistItem(
        jobId: job1Id,
        label: 'Clean condenser coils, fan blades, and ventilation ducts',
        isRequired: true,
        sortOrder: 2,
        result: ChecklistResult.pass,
        comment: 'Vacuumed dust build-up. Airflow restored to nominal 450 CFM.',
      ),
      ChecklistItem(
        jobId: job1Id,
        label: 'Verify safety emergency shutoff mechanism',
        isRequired: true,
        sortOrder: 3,
        result: ChecklistResult.pass,
        comment: 'Tested emergency isolator switch - cuts power cleanly.',
      ),
    ]);

    await db.insertNote(
      JobNote(
        jobId: job1Id,
        text:
            'Customer requested follow-up next quarter for secondary cooling coil replacement.',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
    );

    if (demoSignaturePath.isNotEmpty) {
      await db.insertSignOff(
        SignOff(
          jobId: job1Id,
          signerName: 'David Miller (Store Manager)',
          signatureRelativePath: demoSignaturePath,
          signedAt: now.subtract(const Duration(days: 1)),
          isCurrent: true,
        ),
      );
    }

    // Job 2: In Progress Job
    final job2Id = await db.insertJob(
      ServiceJob(
        title: 'Branch Office Annual Safety Check',
        description:
            'Annual facility code review, emergency lighting check, and fire door clearance inspection.',
        customerId: c2Id,
        address: '1200 Maritime Way, Dock 4, Oakland',
        latitude: 37.8044,
        longitude: -122.2711,
        locationAccuracy: 6.2,
        locationCapturedAt: now.subtract(const Duration(hours: 1)),
        scheduledAt: now,
        priority: JobPriority.medium,
        status: JobStatus.inProgress,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      ),
    );

    await db.batchInsertChecklistItems([
      ChecklistItem(
        jobId: job2Id,
        label:
            'Verify emergency exit pathways and illuminated signs are unobstructed',
        isRequired: true,
        sortOrder: 0,
        result: ChecklistResult.pass,
        comment: 'North and South exit corridors cleared.',
      ),
      ChecklistItem(
        jobId: job2Id,
        label:
            'Check fire extinguisher pressure gauge and annual inspection tag',
        isRequired: true,
        sortOrder: 1,
        result: ChecklistResult.pass,
        comment: 'Unit 4A tagged and verified full.',
      ),
      ChecklistItem(
        jobId: job2Id,
        label: 'Test emergency lighting battery backup systems',
        isRequired: true,
        sortOrder: 2,
        result: ChecklistResult.pending,
      ),
      ChecklistItem(
        jobId: job2Id,
        label: 'Inspect electrical panel clear clearance (min 36 inches)',
        isRequired: true,
        sortOrder: 3,
        result: ChecklistResult.pending,
      ),
    ]);

    await db.insertNote(
      JobNote(
        jobId: job2Id,
        text: 'Technician on site. Testing emergency battery arrays in zone B.',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
    );

    // Job 3: Scheduled Job (Upcoming tomorrow)
    final job3Id = await db.insertJob(
      ServiceJob(
        title: 'Server Room Rack Cabling & Switch Setup',
        description:
            'Terminate 24 patch drops, install 48-port PoE switch, and test uplink continuity.',
        customerId: c3Id,
        address: '45 Medical Center Blvd, Floor 3, San Francisco',
        scheduledAt: now.add(const Duration(days: 1, hours: 2)),
        priority: JobPriority.high,
        status: JobStatus.scheduled,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    );

    await db.batchInsertChecklistItems([
      ChecklistItem(
        jobId: job3Id,
        label: 'Verify network rack mounting and equipment grounding',
        isRequired: true,
        sortOrder: 0,
        result: ChecklistResult.pending,
      ),
      ChecklistItem(
        jobId: job3Id,
        label: 'Test Cat6 cable continuity and wire map on all drops',
        isRequired: true,
        sortOrder: 1,
        result: ChecklistResult.pending,
      ),
      ChecklistItem(
        jobId: job3Id,
        label: 'Label patch panels, wall plates, and switch ports',
        isRequired: true,
        sortOrder: 2,
        result: ChecklistResult.pending,
      ),
    ]);

    // Job 4: Draft Job (Incomplete draft)
    await db.insertJob(
      ServiceJob(
        title: 'Espresso Bar Grinder Motor Diagnostic',
        description:
            'Grinder overheating during morning rush hours. Needs motor stator inspection.',
        customerId: c4Id,
        address: '88 Coffee Lane, Berkeley',
        scheduledAt: now.add(const Duration(days: 3)),
        priority: JobPriority.low,
        status: JobStatus.draft,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Job 5: Cancelled Job
    final job5Id = await db.insertJob(
      ServiceJob(
        title: 'Warehouse Emergency Exit Light Replacement',
        description: 'Replace damaged strobe fixture near bay door 2.',
        customerId: c2Id,
        address: '1200 Maritime Way, Dock 4, Oakland',
        scheduledAt: now.subtract(const Duration(days: 4)),
        priority: JobPriority.medium,
        status: JobStatus.cancelled,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
    );

    // Cancelled history
    await db.updateJobStatusWithTransaction(
      jobId: job5Id,
      nextStatus: JobStatus.cancelled,
      reason: 'Customer postponed due to facility repainting.',
    );

    // Save preferences
    await db.setPreference('onboardingCompleted', 'true');
    await db.setPreference('demoDataLoaded', 'true');
  }
}
