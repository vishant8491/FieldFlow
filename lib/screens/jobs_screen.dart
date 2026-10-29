import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/service_job.dart';
import '../providers/jobs_provider.dart';
import 'settings_screen.dart';
import 'job_form_screen.dart';
import 'job_detail_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSortFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer<JobsProvider>(
          builder: (context, prov, child) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sort & Filter Jobs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            prov.clearFilters();
                            _searchController.clear();
                            Navigator.pop(context);
                          },
                          child: const Text('Reset All'),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Date Filter
                    const Text(
                      'Date Range',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: DateFilterOption.values.map((option) {
                        final isSelected = prov.selectedDateFilter == option;
                        return ChoiceChip(
                          label: Text(option.label),
                          selected: isSelected,
                          onSelected: (selected) {
                            prov.setDateFilter(
                              selected ? option : DateFilterOption.all,
                            );
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Status Filter
                    const Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All Statuses'),
                          selected: prov.selectedStatusFilter == null,
                          onSelected: (selected) {
                            if (selected) prov.setStatusFilter(null);
                          },
                        ),
                        ...JobStatus.values.map((st) {
                          final isSelected = prov.selectedStatusFilter == st;
                          return ChoiceChip(
                            label: Text(st.displayName),
                            selected: isSelected,
                            onSelected: (selected) {
                              prov.setStatusFilter(selected ? st : null);
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Priority Filter
                    const Text(
                      'Priority',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All Priorities'),
                          selected: prov.selectedPriorityFilter == null,
                          onSelected: (selected) {
                            if (selected) prov.setPriorityFilter(null);
                          },
                        ),
                        ...JobPriority.values.map((pr) {
                          final isSelected = prov.selectedPriorityFilter == pr;
                          return ChoiceChip(
                            label: Text(pr.displayName),
                            selected: isSelected,
                            onSelected: (selected) {
                              prov.setPriorityFilter(selected ? pr : null);
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sort Order
                    const Text(
                      'Sort Order',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: JobSortOption.values.map((sort) {
                        final isSelected = prov.sortOption == sort;
                        return ChoiceChip(
                          label: Text(sort.label),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) prov.setSortOption(sort);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Apply Filters'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<JobsProvider>();
    final jobs = provider.filteredJobs;
    final totalJobsCount = provider.allJobs.length;
    final hasActiveFilter = provider.searchQuery.isNotEmpty ||
        provider.selectedStatusFilter != null ||
        provider.selectedPriorityFilter != null ||
        provider.selectedDateFilter != DateFilterOption.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Jobs'),
        actions: [
          IconButton(
            tooltip: 'Filter & Sort',
            icon: Badge(
              isLabelVisible: hasActiveFilter,
              child: const Icon(Icons.filter_list_rounded),
            ),
            onPressed: () => _showSortFilterModal(context),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const JobFormScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Job'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Filter Indicators
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search title, customer, or address...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onChanged: (val) {
                  provider.setSearchQuery(val);
                },
              ),
            ),

            // Active Filter Chips horizontal list
            if (hasActiveFilter)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.close_rounded, size: 14),
                      label: const Text('Clear All'),
                      onPressed: () {
                        _searchController.clear();
                        provider.clearFilters();
                      },
                    ),
                    const SizedBox(width: 6),
                    if (provider.selectedDateFilter != DateFilterOption.all)
                      Chip(
                        label: Text(provider.selectedDateFilter.label),
                        onDeleted: () =>
                            provider.setDateFilter(DateFilterOption.all),
                      ),
                    if (provider.selectedStatusFilter != null) ...[
                      const SizedBox(width: 6),
                      Chip(
                        label: Text(provider.selectedStatusFilter!.displayName),
                        onDeleted: () => provider.setStatusFilter(null),
                      ),
                    ],
                    if (provider.selectedPriorityFilter != null) ...[
                      const SizedBox(width: 6),
                      Chip(
                        label: Text(
                          '${provider.selectedPriorityFilter!.displayName} Priority',
                        ),
                        onDeleted: () => provider.setPriorityFilter(null),
                      ),
                    ],
                  ],
                ),
              ),

            // Jobs Count Subheader
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${jobs.length} of $totalJobsCount jobs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    provider.sortOption.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF2563EB),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // List View
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.loadJobs(),
                child: _buildJobsList(
                  context,
                  jobs,
                  totalJobsCount,
                  hasActiveFilter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsList(
    BuildContext context,
    List<ServiceJob> jobs,
    int totalCount,
    bool hasActiveFilter,
  ) {
    final theme = Theme.of(context);
    final provider = context.read<JobsProvider>();

    if (totalCount == 0) {
      // Empty workspace
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_add,
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'No service jobs yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Create your first job or load sample demo data in Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JobFormScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create New Job'),
              ),
            ],
          ),
        ),
      );
    }

    if (jobs.isEmpty && hasActiveFilter) {
      // No filter results
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'No jobs match your filters',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Try adjusting your search query, priority, or date range.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  provider.clearFilters();
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Reset Filters'),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('EEE, MMM d • h:mm a');

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final customer = provider.getCustomerById(job.customerId);

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JobDetailScreen(jobId: job.id!),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Job title + Status Chip
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: job.status.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: job.status.color.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          job.status.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: job.status.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Customer Name
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        customer?.name ?? 'Customer #${job.customerId}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          job.address,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Footer: Scheduled Time + Priority Chip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(job.scheduledAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.75,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: job.priority.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${job.priority.displayName} Priority',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: job.priority.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
