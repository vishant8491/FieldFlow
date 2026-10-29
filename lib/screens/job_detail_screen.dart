import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/service_job.dart';
import '../models/customer.dart';
import '../models/checklist_item.dart';
import '../models/attachment.dart';
import '../models/job_note.dart';
import '../models/status_event.dart';
import '../models/sign_off.dart';
import '../models/checklist_template.dart';
import '../providers/jobs_provider.dart';
import '../services/attachment_service.dart';
import '../services/pdf_service.dart';
import 'job_form_screen.dart';
import 'inspection_item_dialog.dart';
import 'signature_screen.dart';
import 'photo_view_screen.dart';
import '../widgets/completion_blockers_dialog.dart';

class JobDetailScreen extends StatefulWidget {
  final int jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  ServiceJob? _job;
  Customer? _customer;
  List<ChecklistItem> _checklist = [];
  List<Attachment> _attachments = [];
  List<JobNote> _notes = [];
  List<StatusEvent> _statusHistory = [];
  SignOff? _currentSignOff;

  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadJobData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadJobData() async {
    setState(() => _isLoading = true);
    final provider = context.read<JobsProvider>();

    try {
      final job = provider.getJobById(widget.jobId);
      if (job != null) {
        final cust = provider.getCustomerById(job.customerId);
        final checklist = await provider.getChecklistItems(widget.jobId);
        final attachments = await provider.getAttachments(widget.jobId);
        final notes = await provider.getNotes(widget.jobId);
        final history = await provider.getStatusHistory(widget.jobId);
        final signOff = await provider.getCurrentSignOff(widget.jobId);

        if (mounted) {
          setState(() {
            _job = job;
            _customer = cust;
            _checklist = checklist;
            _attachments = attachments;
            _notes = notes;
            _statusHistory = history;
            _currentSignOff = signOff;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // STATUS TRANSITION ACTIONS
  // ==========================================

  Future<void> _handleStartJob() async {
    final provider = context.read<JobsProvider>();
    try {
      await provider.transitionJobStatus(
        jobId: widget.jobId,
        nextStatus: JobStatus.inProgress,
        reason: 'Technician commenced field service.',
      );
      await _loadJobData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job status changed to In Progress.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Cannot start job: $e')));
    }
  }

  Future<void> _handleCompleteJob() async {
    if (_job == null) return;
    final provider = context.read<JobsProvider>();

    // Check completion blockers
    final blockers = provider.getCompletionBlockers(
      job: _job!,
      checklist: _checklist,
      currentSignOff: _currentSignOff,
    );

    if (blockers.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => CompletionBlockersDialog(blockers: blockers),
      );
      return;
    }

    // Confirm completion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Service Job?'),
        content: const Text(
          'All checklist items and customer sign-off have been recorded.\n\nCompleting the job will mark it as finished and read-only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Completion'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await provider.transitionJobStatus(
          jobId: widget.jobId,
          nextStatus: JobStatus.completed,
          reason:
              'All checklist items verified and customer sign-off recorded.',
          checklist: _checklist,
          currentSignOff: _currentSignOff,
        );
        await _loadJobData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job marked as Completed!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error completing job: $e')));
      }
    }
  }

  Future<void> _handleCancelJob() async {
    final reasonController = TextEditingController();
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Job'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'A non-empty reason is required to cancel an unfinished job:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason *',
                hintText: 'e.g. Client postponed due to renovation',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Job'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a cancellation reason.'),
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel == true && mounted) {
      try {
        final provider = context.read<JobsProvider>();
        await provider.transitionJobStatus(
          jobId: widget.jobId,
          nextStatus: JobStatus.cancelled,
          reason: reasonController.text.trim(),
        );
        await _loadJobData();
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Job cancelled.')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to cancel job: $e')));
      }
    }
  }

  Future<void> _handleReopenJob() async {
    final reasonController = TextEditingController();
    final shouldReopen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen Completed Job'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Reopening will change status back to In Progress and invalidate previous customer sign-off (a fresh sign-off will be required before completing again).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reopening Reason *',
                hintText: 'e.g. Additional compressor diagnostic requested',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
            ),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a reopening reason.'),
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Confirm Reopen'),
          ),
        ],
      ),
    );

    if (shouldReopen == true && mounted) {
      try {
        final provider = context.read<JobsProvider>();
        await provider.reopenJob(
          jobId: widget.jobId,
          reason: reasonController.text.trim(),
        );
        await _loadJobData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Job reopened. Status changed to In Progress; please obtain a new customer signature when ready.',
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to reopen job: $e')));
      }
    }
  }

  // ==========================================
  // PDF REPORT EXPORT
  // ==========================================

  Future<void> _exportPdfReport() async {
    if (_job == null || _customer == null) return;

    setState(() => _isGeneratingPdf = true);
    try {
      await PdfService.instance.shareReportPdf(
        job: _job!,
        customer: _customer!,
        checklistItems: _checklist,
        attachments: _attachments,
        notes: _notes,
        statusHistory: _statusHistory,
        signOff: _currentSignOff,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF report: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ==========================================
  // CHECKLIST INTERACTIONS
  // ==========================================

  Future<void> _openEvaluateChecklistItem(ChecklistItem item) async {
    final updated = await showDialog<ChecklistItem>(
      context: context,
      builder: (context) => InspectionItemDialog(
        item: item,
        isReadOnly: _job?.isReadOnly ?? false,
      ),
    );

    if (updated != null && mounted) {
      try {
        final provider = context.read<JobsProvider>();
        await provider.updateChecklistItem(updated);
        await _loadJobData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Checklist item updated.'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update checklist item: $e')),
        );
      }
    }
  }

  Future<void> _addNewChecklistItem() async {
    final labelController = TextEditingController();
    bool isRequired = true;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Add Checklist Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Checklist Item Label *',
                  hintText: 'e.g. Inspect refrigerant pressure gauges',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Required check before completion'),
                value: isRequired,
                onChanged: (val) {
                  setModalState(() => isRequired = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (labelController.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );

    if (created == true && mounted) {
      try {
        final item = ChecklistItem(
          jobId: widget.jobId,
          label: labelController.text.trim(),
          isRequired: isRequired,
          sortOrder: _checklist.length,
          result: ChecklistResult.pending,
        );

        final provider = context.read<JobsProvider>();
        await provider.addChecklistItem(item);
        await _loadJobData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Checklist item added.'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add checklist item: $e')),
        );
      }
    }
  }

  Future<void> _applyTemplateDialog() async {
    final provider = context.read<JobsProvider>();
    final templates = provider.templates;

    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No inspection templates available.')),
      );
      return;
    }

    final selected = await showDialog<ChecklistTemplate>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Checklist Template'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: templates.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final tpl = templates[index];
              return ListTile(
                title: Text(
                  tpl.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${tpl.items.length} items • ${tpl.description}',
                ),
                onTap: () => Navigator.pop(context, tpl),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null && mounted) {
      await provider.applyTemplateToJob(
        jobId: widget.jobId,
        template: selected,
      );
      await _loadJobData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applied "${selected.name}" template with ${selected.items.length} checklist items.',
          ),
        ),
      );
    }
  }

  // ==========================================
  // EVIDENCE / PHOTO ACTIONS
  // ==========================================

  Future<void> _addPhoto(ImageSource source) async {
    final picked = await AttachmentService.instance.pickImage(source);
    if (picked == null || !mounted) return;

    // Validate size (15MB limit)
    final fileSize = await picked.length();
    if (fileSize > 15 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Image exceeds 15 MB limit. Please select a smaller photo.'),
          ),
        );
      }
      return;
    }

    // Optional caption dialog
    final captionController = TextEditingController();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Photo Evidence'),
        content: TextField(
          controller: captionController,
          decoration: const InputDecoration(
            labelText: 'Photo Caption (Optional)',
            hintText: 'e.g. Compressor serial tag, fan blade wear',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save Photo'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      String? savedRelPath;
      try {
        savedRelPath = await AttachmentService.instance
            .saveImageToPersistentStorage(file: picked, jobId: widget.jobId);

        final att = Attachment(
          jobId: widget.jobId,
          relativePath: savedRelPath,
          caption: captionController.text.trim().isEmpty
              ? null
              : captionController.text.trim(),
          createdAt: DateTime.now(),
        );

        if (!mounted) return;
        final provider = context.read<JobsProvider>();
        await provider.addAttachment(att);
        await _loadJobData();

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo attached to job.')));
      } catch (e) {
        if (savedRelPath != null) {
          // Clean up orphaned file on database write failure
          await AttachmentService.instance.deleteFile(savedRelPath);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save photo: $e')));
      }
    }
  }

  // ==========================================
  // NOTES ACTIONS
  // ==========================================

  Future<void> _addNoteDialog() async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Field Note'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Note Content *',
            hintText: 'Observations, customer discussions, parts required...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (noteController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final note = JobNote(
        jobId: widget.jobId,
        text: noteController.text.trim(),
        createdAt: DateTime.now(),
      );

      final provider = context.read<JobsProvider>();
      await provider.addNote(note);
      await _loadJobData();
    }
  }

  // ==========================================
  // SIGN-OFF ACTION
  // ==========================================

  Future<void> _openSignOffScreen() async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SignatureScreen(
          jobId: widget.jobId,
          initialSignerName: _customer?.name,
        ),
      ),
    );

    if (success == true && mounted) {
      await _loadJobData();
    }
  }

  Future<void> _deleteCurrentJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job?'),
        content: const Text(
          'This will permanently delete this job, its checklist, notes, photos, and signatures.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<JobsProvider>().deleteJob(widget.jobId);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _handlePhotoTap(Attachment att, bool isReadOnly) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PhotoViewScreen(attachment: att, isReadOnly: isReadOnly),
      ),
    );

    if (deleted == true && mounted) {
      await context.read<JobsProvider>().deleteAttachment(att);
      await _loadJobData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_job == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Not Found')),
        body: const Center(child: Text('This job could not be found.')),
      );
    }

    final job = _job!;
    final customer = _customer;
    final isReadOnly = job.isReadOnly;

    return Scaffold(
      appBar: AppBar(
        title: Text('Job #${job.id}'),
        actions: [
          // Export PDF
          if (_isGeneratingPdf)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Export PDF Service Report',
              onPressed: _exportPdfReport,
            ),
          // Edit details
          if (!isReadOnly)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit Job',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JobFormScreen(job: job),
                  ),
                );
                _loadJobData();
              },
            ),
          // Delete
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'delete') {
                _deleteCurrentJob();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('Delete Job', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFF60A5FA),
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.info_outline_rounded, size: 20),
              text: 'Overview',
            ),
            Tab(
              icon: Icon(Icons.checklist_rounded, size: 20),
              text: 'Inspection',
            ),
            Tab(
              icon: Icon(Icons.photo_library_outlined, size: 20),
              text: 'Evidence',
            ),
            Tab(icon: Icon(Icons.timeline_rounded, size: 20), text: 'Activity'),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomWorkflowBar(context, job),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(context, job, customer),
            _buildInspectionTab(context, job),
            _buildEvidenceTab(context, job),
            _buildActivityTab(context, job),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WORKFLOW ACTION BAR
  // ==========================================

  Widget? _buildBottomWorkflowBar(BuildContext context, ServiceJob job) {
    if (job.status == JobStatus.completed) {
      return Container(
        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 20,
              color: Color(0xFF166534),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Job is Completed & Read-Only',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF166534),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _handleReopenJob,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reopen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD97706),
                side: const BorderSide(color: Color(0xFFD97706)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (job.status == JobStatus.cancelled) {
      return Container(
        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: const Row(
          children: [
            Icon(Icons.cancel_outlined, size: 20, color: Color(0xFF991B1B)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Job has been Cancelled',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF991B1B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Unfinished jobs (Draft, Scheduled, In Progress)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Cancel Action
          IconButton(
            tooltip: 'Cancel Job',
            icon: const Icon(Icons.cancel_outlined, color: Colors.grey),
            onPressed: _handleCancelJob,
          ),
          const SizedBox(width: 8),

          // Primary Transition Button
          Expanded(child: _buildPrimaryStatusButton(job)),
        ],
      ),
    );
  }

  Widget _buildPrimaryStatusButton(ServiceJob job) {
    if (job.status == JobStatus.draft) {
      return ElevatedButton.icon(
        onPressed: () async {
          try {
            await context.read<JobsProvider>().transitionJobStatus(
                  jobId: job.id!,
                  nextStatus: JobStatus.scheduled,
                  reason: 'Job scheduled from draft.',
                );
            await _loadJobData();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Cannot schedule: $e')));
          }
        },
        icon: const Icon(Icons.schedule_send_rounded),
        label: const Text('Move to Scheduled'),
      );
    }

    if (job.status == JobStatus.scheduled) {
      return ElevatedButton.icon(
        onPressed: _handleStartJob,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start Job (In Progress)'),
      );
    }

    // In Progress -> Complete Job
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
      onPressed: _handleCompleteJob,
      icon: const Icon(Icons.task_alt_rounded),
      label: const Text('Complete Job'),
    );
  }

  // ==========================================
  // TAB 1: OVERVIEW
  // ==========================================

  Widget _buildOverviewTab(
    BuildContext context,
    ServiceJob job,
    Customer? customer,
  ) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy • h:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status and Priority Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: job.status.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: job.status.color.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: job.status.color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Status: ${job.status.displayName}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: job.status.color,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: job.priority.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${job.priority.displayName} Priority',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: job.priority.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Title & Description
          Text(
            job.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            job.description.isNotEmpty
                ? job.description
                : 'No work description provided.',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),

          // Customer Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.business_rounded,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Customer Contact',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Text(
                    customer?.name ?? 'No customer assigned',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        customer?.phone ?? '-',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  if (customer?.email != null &&
                      customer!.email!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          customer.email!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Schedule & Address Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Service Location & Schedule',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  const Text(
                    'Address:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job.address,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scheduled For:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFormat.format(job.scheduledAt),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (job.completedAt != null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Completed At:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(job.completedAt!),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // GPS Coordinates Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 18,
                            color: Color(0xFF2563EB),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'GPS Verification',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (job.latitude != null)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Color(0xFF16A34A),
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (job.latitude != null && job.longitude != null) ...[
                    Text(
                      '${job.latitude!.toStringAsFixed(6)}, ${job.longitude!.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (job.locationAccuracy != null)
                      Text(
                        'Fix accuracy: ±${job.locationAccuracy!.toStringAsFixed(1)}m',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    if (job.locationCapturedAt != null)
                      Text(
                        'Recorded: ${dateFormat.format(job.locationCapturedAt!)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                  ] else ...[
                    const Text(
                      'No GPS coordinates recorded for this job.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: INSPECTION
  // ==========================================

  Widget _buildInspectionTab(BuildContext context, ServiceJob job) {
    final theme = Theme.of(context);
    final isReadOnly = job.isReadOnly;

    final totalCount = _checklist.length;
    final assessedCount = _checklist.where((i) => i.isAssessed).length;
    final progress = totalCount > 0 ? assessedCount / totalCount : 0.0;

    return Column(
      children: [
        // Progress & Quick Action Header
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.cardTheme.color,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Checklist Progress ($assessedCount/$totalCount)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: const Color(0xFFE2E8F0),
                color: progress == 1.0
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF2563EB),
              ),
              if (!isReadOnly) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addNewChecklistItem,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Item'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _applyTemplateDialog,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Apply Template'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Items List
        Expanded(
          child: _checklist.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fact_check_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No checklist items yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap "Apply Template" or "Add Item" above to initialize your inspection checklist.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : isReadOnly
                  ? ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: _checklist.length,
                      itemBuilder: (context, index) {
                        final item = _checklist[index];
                        return _buildChecklistItemCard(item, isReadOnly);
                      },
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: _checklist.length,
                      // ignore: deprecated_member_use
                      onReorder: (oldIndex, newIndex) async {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final item = _checklist.removeAt(oldIndex);
                        _checklist.insert(newIndex, item);
                        setState(() {});
                        final ids = _checklist.map((e) => e.id!).toList();
                        await context
                            .read<JobsProvider>()
                            .reorderChecklistItems(widget.jobId, ids);
                      },
                      itemBuilder: (context, index) {
                        final item = _checklist[index];
                        return KeyedSubtree(
                          key: ValueKey(item.id),
                          child: _buildChecklistItemCard(item, isReadOnly),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildChecklistItemCard(ChecklistItem item, bool isReadOnly) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openEvaluateChecklistItem(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge Icon
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: item.result.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.result == ChecklistResult.pass
                          ? Icons.check_circle_rounded
                          : item.result == ChecklistResult.fail
                              ? Icons.cancel_rounded
                              : item.result == ChecklistResult.notApplicable
                                  ? Icons.remove_circle_rounded
                                  : Icons.circle_outlined,
                      size: 16,
                      color: item.result.color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: item.result.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: item.result.color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      item.result.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: item.result.color,
                      ),
                    ),
                  ),
                ],
              ),
              if (item.isRequired) ...[
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Text(
                      '* Required check before completion',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              if (item.comment != null && item.comment!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.comment!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: EVIDENCE (PHOTOS)
  // ==========================================

  Widget _buildEvidenceTab(BuildContext context, ServiceJob job) {
    final isReadOnly = job.isReadOnly;

    return Scaffold(
      floatingActionButton: isReadOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt_rounded),
                          title: const Text('Take Photo with Camera'),
                          onTap: () {
                            Navigator.pop(context);
                            _addPhoto(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library_rounded),
                          title: const Text('Choose from Gallery'),
                          onTap: () {
                            Navigator.pop(context);
                            _addPhoto(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('Add Photo'),
            ),
      body: _attachments.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No photo evidence attached',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Attach photos using the camera or gallery to document completed work and site conditions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _attachments.length,
              itemBuilder: (context, index) {
                final att = _attachments[index];
                return _buildPhotoThumbnailCard(att, isReadOnly);
              },
            ),
    );
  }

  Widget _buildPhotoThumbnailCard(Attachment att, bool isReadOnly) {
    return FutureBuilder<Uint8List?>(
      future: AttachmentService.instance.getImageBytes(att.relativePath),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        final hasImage = bytes != null && bytes.isNotEmpty;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _handlePhotoTap(att, isReadOnly),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: hasImage
                      ? Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Missing',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        att.caption != null && att.caption!.isNotEmpty
                            ? att.caption!
                            : 'Photo Evidence',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DateFormat('MMM d').format(att.createdAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 4: ACTIVITY & SIGN-OFF
  // ==========================================

  Widget _buildActivityTab(BuildContext context, ServiceJob job) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final isReadOnly = job.isReadOnly;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: Customer Sign-Off
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.draw_rounded,
                            size: 20,
                            color: Color(0xFF2563EB),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Customer Sign-Off',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (_currentSignOff != null)
                        const Chip(
                          label: Text('Signed'),
                          backgroundColor: Color(0xFFDCFCE7),
                          labelStyle: TextStyle(
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        )
                      else
                        const Chip(
                          label: Text('Pending'),
                          backgroundColor: Color(0xFFFEF3C7),
                          labelStyle: TextStyle(
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (_currentSignOff != null) ...[
                    Text(
                      'Signer: ${_currentSignOff!.signerName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Signed: ${dateFormat.format(_currentSignOff!.signedAt)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<Uint8List?>(
                      future: AttachmentService.instance.getImageBytes(
                        _currentSignOff!.signatureRelativePath,
                      ),
                      builder: (context, snapshot) {
                        final bytes = snapshot.data;
                        if (bytes != null && bytes.isNotEmpty) {
                          return Container(
                            height: 80,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Image.memory(bytes, fit: BoxFit.contain),
                          );
                        }
                        return const Text(
                          'Signature image not found in storage',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        );
                      },
                    ),
                    if (!isReadOnly) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openSignOffScreen,
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Update Customer Signature'),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      'No customer signature recorded yet. A signature is required to complete this job.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    if (!isReadOnly) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _openSignOffScreen,
                        icon: const Icon(Icons.draw_rounded),
                        label: const Text('Capture Customer Signature'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Field Notes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.notes_rounded,
                            size: 20,
                            color: Color(0xFF2563EB),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Technician Notes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (!isReadOnly)
                        IconButton(
                          icon: const Icon(Icons.add_rounded),
                          tooltip: 'Add Note',
                          onPressed: _addNoteDialog,
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (_notes.isEmpty)
                    const Text(
                      'No field notes recorded yet.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    )
                  else
                    ..._notes.map(
                      (note) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.text,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateFormat.format(note.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Status Transition Audit History
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 20,
                        color: Color(0xFF2563EB),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Status History Audit Trail',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (_statusHistory.isEmpty)
                    const Text(
                      'No status transitions recorded.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    )
                  else
                    ..._statusHistory.map((ev) {
                      final title = ev.previousStatus != null
                          ? '${ev.previousStatus!.displayName} -> ${ev.nextStatus.displayName}'
                          : 'Initial: ${ev.nextStatus.displayName}';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: ev.nextStatus.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (ev.reason != null &&
                                      ev.reason!.isNotEmpty)
                                    Text(
                                      ev.reason!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  Text(
                                    dateFormat.format(ev.timestamp),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
