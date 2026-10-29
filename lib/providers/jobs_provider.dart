import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/service_job.dart';
import '../models/checklist_item.dart';
import '../models/attachment.dart';
import '../models/job_note.dart';
import '../models/status_event.dart';
import '../models/sign_off.dart';
import '../models/checklist_template.dart';
import '../models/template_item.dart';
import '../services/database_service.dart';
import '../services/attachment_service.dart';
import '../services/demo_data_seeder.dart';

enum JobSortOption {
  scheduleAsc('Schedule (Earliest First)'),
  scheduleDesc('Schedule (Latest First)'),
  updatedDesc('Last Updated');

  final String label;
  const JobSortOption(this.label);
}

enum DateFilterOption {
  all('All Dates'),
  today('Today'),
  upcoming('Upcoming'),
  overdue('Overdue Unfinished');

  final String label;
  const DateFilterOption(this.label);
}

class JobsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final AttachmentService _attachmentService = AttachmentService.instance;

  bool _isLoading = true;
  bool _onboardingCompleted = false;
  bool _demoDataLoaded = false;

  List<ServiceJob> _allJobs = [];
  List<Customer> _customers = [];
  List<ChecklistTemplate> _templates = [];

  // Active filters and search
  String _searchQuery = '';
  JobStatus? _selectedStatusFilter;
  JobPriority? _selectedPriorityFilter;
  DateFilterOption _selectedDateFilter = DateFilterOption.all;
  JobSortOption _sortOption = JobSortOption.scheduleAsc;

  // Getters
  bool get isLoading => _isLoading;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get demoDataLoaded => _demoDataLoaded;
  List<Customer> get customers => _customers;
  List<ChecklistTemplate> get templates => _templates;
  List<ServiceJob> get allJobs => _allJobs;

  String get searchQuery => _searchQuery;
  JobStatus? get selectedStatusFilter => _selectedStatusFilter;
  JobPriority? get selectedPriorityFilter => _selectedPriorityFilter;
  DateFilterOption get selectedDateFilter => _selectedDateFilter;
  JobSortOption get sortOption => _sortOption;

  JobsProvider() {
    initialize();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final obDone = await _db.getPreference('onboardingCompleted');
      final demoDone = await _db.getPreference('demoDataLoaded');
      _onboardingCompleted = obDone == 'true';
      _demoDataLoaded = demoDone == 'true';

      await loadCustomers();
      await loadTemplates();
      await loadJobs();
    } catch (e) {
      debugPrint('Initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // DASHBOARD METRICS
  // ==========================================

  List<ServiceJob> get todayJobs {
    final now = DateTime.now();
    return _allJobs.where((j) {
      return j.status != JobStatus.draft &&
          j.scheduledAt.year == now.year &&
          j.scheduledAt.month == now.month &&
          j.scheduledAt.day == now.day;
    }).toList();
  }

  List<ServiceJob> get upcomingJobs {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return _allJobs.where((j) {
      return j.status != JobStatus.draft &&
          j.scheduledAt.isAfter(todayEnd) &&
          !j.isReadOnly;
    }).toList();
  }

  List<ServiceJob> get overdueJobs {
    final now = DateTime.now();
    return _allJobs.where((j) {
      return j.scheduledAt.isBefore(now) &&
          (j.status == JobStatus.scheduled || j.status == JobStatus.inProgress);
    }).toList();
  }

  int get inProgressCount =>
      _allJobs.where((j) => j.status == JobStatus.inProgress).length;

  int get completedCount =>
      _allJobs.where((j) => j.status == JobStatus.completed).length;

  List<ServiceJob> get recentActivityJobs {
    final sorted = List<ServiceJob>.from(_allJobs)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(5).toList();
  }

  // ==========================================
  // FILTERED JOBS
  // ==========================================

  List<ServiceJob> get filteredJobs {
    List<ServiceJob> list = List.from(_allJobs);
    final now = DateTime.now();

    // 1. Search Query (Title, Customer Name, Address)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((job) {
        final cust = getCustomerById(job.customerId);
        final custName = cust?.name.toLowerCase() ?? '';
        return job.title.toLowerCase().contains(q) ||
            job.address.toLowerCase().contains(q) ||
            custName.contains(q);
      }).toList();
    }

    // 2. Status Filter
    if (_selectedStatusFilter != null) {
      list = list.where((j) => j.status == _selectedStatusFilter).toList();
    }

    // 3. Priority Filter
    if (_selectedPriorityFilter != null) {
      list = list.where((j) => j.priority == _selectedPriorityFilter).toList();
    }

    // 4. Date Filter
    if (_selectedDateFilter == DateFilterOption.today) {
      list = list.where((j) {
        return j.scheduledAt.year == now.year &&
            j.scheduledAt.month == now.month &&
            j.scheduledAt.day == now.day;
      }).toList();
    } else if (_selectedDateFilter == DateFilterOption.upcoming) {
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      list = list.where((j) => j.scheduledAt.isAfter(todayEnd)).toList();
    } else if (_selectedDateFilter == DateFilterOption.overdue) {
      list = list.where((j) {
        return j.scheduledAt.isBefore(now) &&
            (j.status == JobStatus.scheduled ||
                j.status == JobStatus.inProgress);
      }).toList();
    }

    // 5. Sorting
    switch (_sortOption) {
      case JobSortOption.scheduleAsc:
        list.sort((a, b) {
          if (a.status == JobStatus.draft && b.status != JobStatus.draft) {
            return 1;
          }
          if (b.status == JobStatus.draft && a.status != JobStatus.draft) {
            return -1;
          }
          return a.scheduledAt.compareTo(b.scheduledAt);
        });
        break;
      case JobSortOption.scheduleDesc:
        list.sort((a, b) {
          if (a.status == JobStatus.draft && b.status != JobStatus.draft) {
            return 1;
          }
          if (b.status == JobStatus.draft && a.status != JobStatus.draft) {
            return -1;
          }
          return b.scheduledAt.compareTo(a.scheduledAt);
        });
        break;
      case JobSortOption.updatedDesc:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }

    return list;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStatusFilter(JobStatus? status) {
    _selectedStatusFilter = status;
    notifyListeners();
  }

  void setPriorityFilter(JobPriority? priority) {
    _selectedPriorityFilter = priority;
    notifyListeners();
  }

  void setDateFilter(DateFilterOption option) {
    _selectedDateFilter = option;
    notifyListeners();
  }

  void setSortOption(JobSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedStatusFilter = null;
    _selectedPriorityFilter = null;
    _selectedDateFilter = DateFilterOption.all;
    _sortOption = JobSortOption.scheduleAsc;
    notifyListeners();
  }

  // ==========================================
  // CUSTOMERS
  // ==========================================

  Future<void> loadCustomers() async {
    _customers = await _db.getCustomers();
    notifyListeners();
  }

  Customer? getCustomerById(int id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<int> saveCustomer(Customer customer) async {
    int id;
    if (customer.id == null) {
      id = await _db.insertCustomer(customer);
    } else {
      await _db.updateCustomer(customer);
      id = customer.id!;
    }
    await loadCustomers();
    return id;
  }

  Future<void> deleteCustomer(int id) async {
    await _db.deleteCustomer(id);
    await loadCustomers();
  }

  Future<int> getCustomerJobCount(int id) async {
    return await _db.getCustomerJobCount(id);
  }

  // ==========================================
  // JOBS
  // ==========================================

  Future<void> loadJobs() async {
    _allJobs = await _db.getJobs();
    notifyListeners();
  }

  ServiceJob? getJobById(int id) {
    try {
      return _allJobs.firstWhere((j) => j.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<int> saveJob(ServiceJob job) async {
    int id;
    if (job.id == null) {
      id = await _db.insertJob(job);
    } else {
      final existing = await _db.getJobById(job.id!);
      await _db.updateJob(job);
      id = job.id!;
      if (existing != null && existing.status != job.status) {
        await _db.insertStatusEvent(
          jobId: id,
          previousStatus: existing.status.name,
          nextStatus: job.status.name,
          reason: 'Job status updated to ${job.status.displayName}',
        );
      }
    }
    await loadJobs();
    return id;
  }

  Future<void> deleteJob(int id) async {
    // Delete associated files on disk first
    final attachments = await _db.getAttachmentsForJob(id);
    for (final att in attachments) {
      await _attachmentService.deleteFile(att.relativePath);
    }
    final signOffs = await _db.getSignOffsForJob(id);
    for (final so in signOffs) {
      await _attachmentService.deleteFile(so.signatureRelativePath);
    }

    await _db.deleteJob(id);
    await loadJobs();
  }

  // ==========================================
  // WORKFLOW & STATUS TRANSITIONS
  // ==========================================

  List<String> getCompletionBlockers({
    required ServiceJob job,
    required List<ChecklistItem> checklist,
    required SignOff? currentSignOff,
  }) {
    final List<String> blockers = [];

    // 1. Current status check
    if (job.status != JobStatus.inProgress) {
      blockers.add(
        "Job must be 'In Progress' to complete (currently '${job.status.displayName}').",
      );
    }

    // 2. Checklist checks
    int unassessedCount = 0;
    for (final item in checklist) {
      if (item.isRequired && item.result == ChecklistResult.pending) {
        unassessedCount++;
      } else if (item.result == ChecklistResult.fail) {
        if (item.comment == null || item.comment!.trim().isEmpty) {
          blockers.add(
            "Checklist item '${item.label}' failed without an explanatory comment.",
          );
        }
      } else if (item.isRequired &&
          item.result == ChecklistResult.notApplicable) {
        if (item.comment == null || item.comment!.trim().isEmpty) {
          blockers.add(
            "Required checklist item '${item.label}' marked N/A without a justification reason.",
          );
        }
      }
    }

    if (unassessedCount > 0) {
      blockers.add(
        "$unassessedCount required inspection checklist item(s) are still pending.",
      );
    }

    // 3. Sign-off check
    if (currentSignOff == null) {
      blockers.add("Customer sign-off and signature are missing.");
    } else {
      if (currentSignOff.signerName.trim().isEmpty) {
        blockers.add("Customer signer name is missing from sign-off record.");
      }
      if (currentSignOff.signatureRelativePath.trim().isEmpty) {
        blockers.add("Customer signature drawing is missing.");
      }
    }

    return blockers;
  }

  /// Changes status according to workflow rules
  Future<void> transitionJobStatus({
    required int jobId,
    required JobStatus nextStatus,
    String? reason,
    List<ChecklistItem>? checklist,
    SignOff? currentSignOff,
  }) async {
    final job = getJobById(jobId);
    if (job == null) throw Exception('Job #$jobId not found');

    // Rule: Completed jobs cannot transition (must use reopenJob)
    if (job.status == JobStatus.completed) {
      throw Exception(
        'Completed jobs are read-only and cannot change status. Use Reopen Job instead.',
      );
    }

    // Rule: Cancelled jobs are terminal
    if (job.status == JobStatus.cancelled) {
      throw Exception('Cancelled jobs cannot change status.');
    }

    // Rule: Cancellation requires non-empty reason and can only cancel unfinished jobs
    if (nextStatus == JobStatus.cancelled) {
      if (reason == null || reason.trim().isEmpty) {
        throw Exception('A reason is required to cancel an unfinished job.');
      }
    }

    // Rule: In-progress can only be entered from scheduled
    if (nextStatus == JobStatus.inProgress &&
        job.status != JobStatus.scheduled) {
      throw Exception(
        'Only scheduled jobs can be moved to In Progress (currently ${job.status.displayName}).',
      );
    }

    // Rule: Scheduled can only be entered from draft
    if (nextStatus == JobStatus.scheduled && job.status != JobStatus.draft) {
      throw Exception(
        'Only draft jobs can be moved to Scheduled (currently ${job.status.displayName}).',
      );
    }

    // Rule: Completed can only be entered from inProgress
    if (nextStatus == JobStatus.completed &&
        job.status != JobStatus.inProgress) {
      throw Exception(
        'Only in-progress jobs can be completed (currently ${job.status.displayName}).',
      );
    }

    // Rule: Completion blockers
    if (nextStatus == JobStatus.completed) {
      final items = checklist ?? await _db.getChecklistItemsForJob(jobId);
      final signOff =
          currentSignOff ?? await _db.getCurrentSignOffForJob(jobId);
      final blockers = getCompletionBlockers(
        job: job,
        checklist: items,
        currentSignOff: signOff,
      );
      if (blockers.isNotEmpty) {
        throw Exception(
          'Cannot complete job. Please resolve the following:\n• ${blockers.join('\n• ')}',
        );
      }
    }

    // Rule: Scheduling requires customer, address, and scheduled date
    if (nextStatus == JobStatus.scheduled) {
      if (job.customerId <= 0 || job.address.trim().isEmpty) {
        throw Exception(
          'A valid customer and service address are required to schedule a job.',
        );
      }
    }

    await _db.updateJobStatusWithTransaction(
      jobId: jobId,
      nextStatus: nextStatus,
      reason: reason,
    );

    await loadJobs();
  }

  /// Reopening a completed job
  Future<void> reopenJob({required int jobId, required String reason}) async {
    await _db.reopenJobWithTransaction(jobId: jobId, reason: reason);
    await loadJobs();
  }

  // ==========================================
  // CHECKLIST ITEMS
  // ==========================================

  Future<List<ChecklistItem>> getChecklistItems(int jobId) async {
    return await _db.getChecklistItemsForJob(jobId);
  }

  Future<int> addChecklistItem(ChecklistItem item) async {
    final id = await _db.insertChecklistItem(item);
    return id;
  }

  Future<void> updateChecklistItem(ChecklistItem item) async {
    await _db.updateChecklistItem(item);
  }

  Future<void> deleteChecklistItem(int id) async {
    await _db.deleteChecklistItem(id);
  }

  Future<void> reorderChecklistItems(int jobId, List<int> orderedIds) async {
    await _db.reorderChecklistItems(jobId, orderedIds);
  }

  Future<void> applyTemplateToJob({
    required int jobId,
    required ChecklistTemplate template,
  }) async {
    final items = template.items.map((tItem) {
      return ChecklistItem(
        jobId: jobId,
        label: tItem.label,
        isRequired: tItem.isRequired,
        sortOrder: tItem.sortOrder,
        result: ChecklistResult.pending,
      );
    }).toList();

    await _db.batchInsertChecklistItems(items);
  }

  // ==========================================
  // ATTACHMENTS
  // ==========================================

  Future<List<Attachment>> getAttachments(int jobId) async {
    return await _db.getAttachmentsForJob(jobId);
  }

  Future<int> addAttachment(Attachment attachment) async {
    return await _db.insertAttachment(attachment);
  }

  Future<void> deleteAttachment(Attachment attachment) async {
    if (attachment.id != null) {
      await _db.deleteAttachment(attachment.id!);
    }
    await _attachmentService.deleteFile(attachment.relativePath);
  }

  // ==========================================
  // NOTES
  // ==========================================

  Future<List<JobNote>> getNotes(int jobId) async {
    return await _db.getNotesForJob(jobId);
  }

  Future<int> addNote(JobNote note) async {
    return await _db.insertNote(note);
  }

  Future<void> deleteNote(int id) async {
    await _db.deleteNote(id);
  }

  // ==========================================
  // STATUS HISTORY & SIGN-OFF
  // ==========================================

  Future<List<StatusEvent>> getStatusHistory(int jobId) async {
    return await _db.getStatusHistoryForJob(jobId);
  }

  Future<SignOff?> getCurrentSignOff(int jobId) async {
    return await _db.getCurrentSignOffForJob(jobId);
  }

  Future<List<SignOff>> getAllSignOffs(int jobId) async {
    return await _db.getSignOffsForJob(jobId);
  }

  Future<int> saveSignOff(SignOff signOff) async {
    return await _db.insertSignOff(signOff);
  }

  // ==========================================
  // TEMPLATES
  // ==========================================

  Future<void> loadTemplates() async {
    _templates = await _db.getTemplates();
    notifyListeners();
  }

  Future<int> saveTemplate(
    ChecklistTemplate template,
    List<TemplateItem> items,
  ) async {
    int id;
    if (template.id == null) {
      id = await _db.insertTemplate(template, items);
    } else {
      await _db.updateTemplate(template, items);
      id = template.id!;
    }
    await loadTemplates();
    return id;
  }

  Future<void> deleteTemplate(int id) async {
    await _db.deleteTemplate(id);
    await loadTemplates();
  }

  // ==========================================
  // ONBOARDING & WORKSPACE SEEDING
  // ==========================================

  Future<void> startEmptyWorkspace() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Seed the default templates so technician has starter inspection checklists
      await DemoDataSeeder.seedTemplates(_db);
      await _db.setPreference('onboardingCompleted', 'true');
      _onboardingCompleted = true;
      _demoDataLoaded = false;
      await loadTemplates();
      await loadCustomers();
      await loadJobs();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDemoWorkspace() async {
    _isLoading = true;
    notifyListeners();

    try {
      await DemoDataSeeder.seedDemoWorkspace(
        db: _db,
        attachmentService: _attachmentService,
      );
      _onboardingCompleted = true;
      _demoDataLoaded = true;
      await loadTemplates();
      await loadCustomers();
      await loadJobs();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearAllAppData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.clearAllData();
      await _attachmentService.clearAllStorageFiles();
      _onboardingCompleted = false;
      _demoDataLoaded = false;
      _allJobs = [];
      _customers = [];
      _templates = [];
      clearFilters();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
