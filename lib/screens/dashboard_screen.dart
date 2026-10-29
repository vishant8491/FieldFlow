import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/service_job.dart';
import '../providers/jobs_provider.dart';
import 'settings_screen.dart';
import 'job_form_screen.dart';
import 'job_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int tabIndex)? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  void _navigateToJobsWithFilter(
    BuildContext context, {
    JobStatus? status,
    DateFilterOption? dateOption,
  }) {
    final provider = context.read<JobsProvider>();
    provider.clearFilters();
    if (status != null) provider.setStatusFilter(status);
    if (dateOption != null) provider.setDateFilter(dateOption);

    if (onNavigateTab != null) {
      onNavigateTab!(1); // Index 1 is Jobs screen
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<JobsProvider>();
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('FieldFlow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.loadJobs(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Greeting and Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operations Dashboard',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          today,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const JobFormScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New Job'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Metrics Row 1: Today & In-Progress
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        title: "Today's Jobs",
                        count: provider.todayJobs.length,
                        icon: Icons.today_rounded,
                        accentColor: const Color(0xFF2563EB),
                        onTap: () => _navigateToJobsWithFilter(
                          context,
                          dateOption: DateFilterOption.today,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        title: 'In Progress',
                        count: provider.inProgressCount,
                        icon: Icons.hourglass_top_rounded,
                        accentColor: const Color(0xFFD97706),
                        onTap: () => _navigateToJobsWithFilter(
                          context,
                          status: JobStatus.inProgress,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Metrics Row 2: Overdue, Upcoming, Completed
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        title: 'Overdue',
                        count: provider.overdueJobs.length,
                        icon: Icons.warning_amber_rounded,
                        accentColor: provider.overdueJobs.isNotEmpty
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF64748B),
                        onTap: () => _navigateToJobsWithFilter(
                          context,
                          dateOption: DateFilterOption.overdue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        title: 'Upcoming',
                        count: provider.upcomingJobs.length,
                        icon: Icons.upcoming_rounded,
                        accentColor: const Color(0xFF0284C7),
                        onTap: () => _navigateToJobsWithFilter(
                          context,
                          dateOption: DateFilterOption.upcoming,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        title: 'Completed',
                        count: provider.completedCount,
                        icon: Icons.check_circle_outline_rounded,
                        accentColor: const Color(0xFF16A34A),
                        onTap: () => _navigateToJobsWithFilter(
                          context,
                          status: JobStatus.completed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Recent Activity Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (onNavigateTab != null) onNavigateTab!(1);
                      },
                      child: const Text('View All Jobs'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (provider.recentActivityJobs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 40,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No jobs created yet',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap "New Job" above to schedule your first service job.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...provider.recentActivityJobs.map((job) {
                    final customer = provider.getCustomerById(job.customerId);
                    return _buildJobSummaryTile(context, job, customer);
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20, color: accentColor),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobSummaryTile(
    BuildContext context,
    ServiceJob job,
    dynamic customer,
  ) {
    final dateFormat = DateFormat('MMM d • h:mm a');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          job.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              customer?.name ?? 'No customer assigned',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 12,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(job.scheduledAt),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: job.status.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: job.status.color.withValues(alpha: 0.4),
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
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: job.priority.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  job.priority.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: job.priority.color,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailScreen(jobId: job.id!),
            ),
          );
        },
      ),
    );
  }
}
