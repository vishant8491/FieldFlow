import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/service_job.dart';
import '../models/customer.dart';
import '../models/checklist_item.dart';
import '../models/attachment.dart';
import '../models/job_note.dart';
import '../models/status_event.dart';
import '../models/sign_off.dart';
import 'attachment_service.dart';

class PdfService {
  static final PdfService instance = PdfService._internal();
  PdfService._internal();

  Future<Uint8List> generateReportPdf({
    required ServiceJob job,
    required Customer customer,
    required List<ChecklistItem> checklistItems,
    required List<Attachment> attachments,
    required List<JobNote> notes,
    required List<StatusEvent> statusHistory,
    SignOff? signOff,
  }) async {
    final pdf = pw.Document(
      title: 'FieldFlow Report #${job.id}',
      author: 'FieldFlow Mobile',
    );

    final dateFormat = DateFormat('MMM d, yyyy, h:mm a');
    final dateOnlyFormat = DateFormat('MMM d, yyyy');

    // Pre-load signature image bytes if available
    pw.MemoryImage? signatureImage;
    if (signOff != null && signOff.signatureRelativePath.isNotEmpty) {
      try {
        final bytes = await AttachmentService.instance
            .getImageBytes(signOff.signatureRelativePath);
        if (bytes != null && bytes.isNotEmpty) {
          signatureImage = pw.MemoryImage(bytes);
        }
      } catch (_) {}
    }

    // Pre-load attachment image bytes safely
    final List<Map<String, dynamic>> loadedPhotos = [];
    for (final att in attachments) {
      try {
        final bytes =
            await AttachmentService.instance.getImageBytes(att.relativePath);
        if (bytes != null && bytes.isNotEmpty) {
          loadedPhotos.add({
            'image': pw.MemoryImage(bytes),
            'caption': att.caption ?? 'Photo Evidence',
            'createdAt': att.createdAt,
          });
        } else {
          loadedPhotos.add({
            'missing': true,
            'caption': att.caption ?? 'Photo Evidence (File Missing)',
            'createdAt': att.createdAt,
          });
        }
      } catch (_) {
        loadedPhotos.add({
          'missing': true,
          'caption': att.caption ?? 'Photo Evidence (Load Error)',
          'createdAt': att.createdAt,
        });
      }
    }

    final bool isDraft = job.status != JobStatus.completed;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            margin: const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.blueGrey200, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FIELDFLOW SERVICE REPORT',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1E293B'),
                      ),
                    ),
                    pw.Text(
                      'ID: FF-JOB-${job.id?.toString().padLeft(4, '0') ?? 'NEW'}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: isDraft
                        ? PdfColor.fromHex('#FEF3C7') // Amber light
                        : PdfColor.fromHex('#DCFCE7'), // Green light
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(
                      color: isDraft
                          ? PdfColor.fromHex('#D97706')
                          : PdfColor.fromHex('#16A34A'),
                      width: 1,
                    ),
                  ),
                  child: pw.Text(
                    isDraft ? 'DRAFT REPORT' : 'COMPLETED REPORT',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: isDraft
                          ? PdfColor.fromHex('#92400E')
                          : PdfColor.fromHex('#166534'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            margin: const pw.EdgeInsets.only(top: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.blueGrey100, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated ${dateFormat.format(DateTime.now())} | FieldFlow Operational Snapshot',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) => [
          // Section 1: Overview
          _buildSectionHeader('1. Job & Customer Overview'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            job.title,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#0F172A'),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            job.description.isNotEmpty
                                ? job.description
                                : 'No description provided.',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey800,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Address:',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            job.address,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Customer:', customer.name),
                          _buildDetailRow('Phone:', customer.phone),
                          if (customer.email != null &&
                              customer.email!.isNotEmpty)
                            _buildDetailRow('Email:', customer.email!),
                          _buildDetailRow(
                            'Priority:',
                            job.priority.displayName,
                          ),
                          _buildDetailRow('Status:', job.status.displayName),
                          _buildDetailRow(
                            'Scheduled:',
                            dateFormat.format(job.scheduledAt),
                          ),
                          if (job.completedAt != null)
                            _buildDetailRow(
                              'Completed:',
                              dateFormat.format(job.completedAt!),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (job.latitude != null && job.longitude != null) ...[
                  pw.Divider(color: PdfColors.grey300, height: 16),
                  pw.Row(
                    children: [
                      pw.Text(
                        'Location Fix: ',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '${job.latitude!.toStringAsFixed(6)}, ${job.longitude!.toStringAsFixed(6)}'
                        '${job.locationAccuracy != null ? ' (±${job.locationAccuracy!.toStringAsFixed(1)}m)' : ''}'
                        '${job.locationCapturedAt != null ? ' | Captured: ${dateFormat.format(job.locationCapturedAt!)}' : ''}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Section 2: Checklist Items
          _buildSectionHeader('2. Inspection Checklist'),
          pw.SizedBox(height: 8),
          if (checklistItems.isEmpty)
            pw.Text(
              'No inspection checklist items recorded for this job.',
              style: const pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(3.0),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(2.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('#', isHeader: true),
                    _buildTableCell('Checklist Item', isHeader: true),
                    _buildTableCell('Result', isHeader: true),
                    _buildTableCell('Notes / Comments', isHeader: true),
                  ],
                ),
                ...checklistItems.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  return pw.TableRow(
                    children: [
                      _buildTableCell('$idx'),
                      _buildTableCell(
                        item.isRequired ? '${item.label} *' : item.label,
                      ),
                      _buildResultCell(item.result),
                      _buildTableCell(item.comment ?? '-'),
                    ],
                  );
                }),
              ],
            ),
          pw.SizedBox(height: 16),

          // Section 3: Photo Evidence
          _buildSectionHeader('3. Photographic Evidence'),
          pw.SizedBox(height: 8),
          if (loadedPhotos.isEmpty)
            pw.Text(
              'No photo attachments recorded for this job.',
              style: const pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
              ),
            )
          else
            pw.Wrap(
              spacing: 12,
              runSpacing: 12,
              children: loadedPhotos.map((photo) {
                if (photo['missing'] == true) {
                  return pw.Container(
                    width: 155,
                    height: 140,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          '[Missing Image]',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          photo['caption'] as String,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return pw.Container(
                  width: 155,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        height: 110,
                        alignment: pw.Alignment.center,
                        child: pw.Image(
                          photo['image'] as pw.MemoryImage,
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        photo['caption'] as String,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        maxLines: 2,
                      ),
                      pw.Text(
                        dateOnlyFormat.format(photo['createdAt'] as DateTime),
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          pw.SizedBox(height: 16),

          // Section 4: Notes
          _buildSectionHeader('4. Technician Field Notes'),
          pw.SizedBox(height: 8),
          if (notes.isEmpty)
            pw.Text(
              'No field notes recorded for this job.',
              style: const pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
              ),
            )
          else
            pw.Column(
              children: notes.map((note) {
                return pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    border: pw.Border.all(color: PdfColors.grey200),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        note.text,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        dateFormat.format(note.createdAt),
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          pw.SizedBox(height: 16),

          // Section 5: Sign-Off
          _buildSectionHeader('5. Customer Sign-Off & Acknowledgement'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (signOff != null && signatureImage != null) ...[
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Authorized Signer:',
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey600,
                              ),
                            ),
                            pw.Text(
                              signOff.signerName,
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#0F172A'),
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'Signed On:',
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey600,
                              ),
                            ),
                            pw.Text(
                              dateFormat.format(signOff.signedAt),
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Container(
                        width: 140,
                        height: 65,
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          color: PdfColors.white,
                        ),
                        child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                      ),
                    ],
                  ),
                ] else ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    color: PdfColors.amber50,
                    child: pw.Text(
                      'No current customer signature recorded. Customer sign-off is required to finalize job completion.',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.amber900,
                      ),
                    ),
                  ),
                ],
                pw.SizedBox(height: 8),
                pw.Text(
                  'Acknowledgement Notice: This signature confirms customer acknowledgment of services described above. It is recorded as a local operational snapshot and does not constitute a certified digital identity verification.',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.grey600,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Section 6: Activity History
          _buildSectionHeader('6. Status & Activity Audit Trail'),
          pw.SizedBox(height: 8),
          if (statusHistory.isEmpty)
            pw.Text(
              'No status transition history recorded.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(2.0),
                2: const pw.FlexColumnWidth(3.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildTableCell('Timestamp', isHeader: true),
                    _buildTableCell('Status Change', isHeader: true),
                    _buildTableCell('Reason / Context', isHeader: true),
                  ],
                ),
                ...statusHistory.map((ev) {
                  final transition = ev.previousStatus != null
                      ? '${ev.previousStatus!.displayName} -> ${ev.nextStatus.displayName}'
                      : 'Initial -> ${ev.nextStatus.displayName}';
                  return pw.TableRow(
                    children: [
                      _buildTableCell(dateFormat.format(ev.timestamp)),
                      _buildTableCell(transition),
                      _buildTableCell(ev.reason ?? '-'),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );

    return await pdf.save();
  }

  Future<void> shareReportPdf({
    required ServiceJob job,
    required Customer customer,
    required List<ChecklistItem> checklistItems,
    required List<Attachment> attachments,
    required List<JobNote> notes,
    required List<StatusEvent> statusHistory,
    SignOff? signOff,
  }) async {
    final bytes = await generateReportPdf(
      job: job,
      customer: customer,
      checklistItems: checklistItems,
      attachments: attachments,
      notes: notes,
      statusHistory: statusHistory,
      signOff: signOff,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'FieldFlow_Job_${job.id ?? 0}_Report.pdf',
    );
  }

  pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey300, width: 1),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#1E293B'),
        ),
      ),
    );
  }

  pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 65,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey800 : PdfColors.grey900,
        ),
      ),
    );
  }

  pw.Widget _buildResultCell(ChecklistResult result) {
    PdfColor bgColor;
    PdfColor textColor;

    switch (result) {
      case ChecklistResult.pass:
        bgColor = PdfColor.fromHex('#DCFCE7');
        textColor = PdfColor.fromHex('#166534');
        break;
      case ChecklistResult.fail:
        bgColor = PdfColor.fromHex('#FEE2E2');
        textColor = PdfColor.fromHex('#991B1B');
        break;
      case ChecklistResult.notApplicable:
        bgColor = PdfColor.fromHex('#F1F5F9');
        textColor = PdfColor.fromHex('#475569');
        break;
      case ChecklistResult.pending:
        bgColor = PdfColor.fromHex('#F3F4F6');
        textColor = PdfColor.fromHex('#6B7280');
        break;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(
          result.displayName.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
