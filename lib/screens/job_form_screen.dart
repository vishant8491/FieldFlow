import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/service_job.dart';
import '../providers/jobs_provider.dart';
import '../services/location_service.dart';
import 'customer_form_screen.dart';

class JobFormScreen extends StatefulWidget {
  final ServiceJob? job;

  const JobFormScreen({super.key, this.job});

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  int? _selectedCustomerId;
  late DateTime _scheduledAt;
  late JobPriority _selectedPriority;
  late JobStatus _status;

  double? _locationAccuracy;
  DateTime? _locationCapturedAt;

  bool _isSaving = false;
  bool _isLocating = false;
  bool _hasModified = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.job;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _addressController = TextEditingController(text: existing?.address ?? '');
    _latitudeController = TextEditingController(
      text: existing?.latitude != null ? existing!.latitude.toString() : '',
    );
    _longitudeController = TextEditingController(
      text: existing?.longitude != null ? existing!.longitude.toString() : '',
    );

    _selectedCustomerId = existing?.customerId;
    _scheduledAt =
        existing?.scheduledAt ?? DateTime.now().add(const Duration(hours: 2));
    _selectedPriority = existing?.priority ?? JobPriority.medium;
    _status = existing?.status ?? JobStatus.scheduled;

    _locationAccuracy = existing?.locationAccuracy;
    _locationCapturedAt = existing?.locationCapturedAt;

    _titleController.addListener(_markModified);
    _descriptionController.addListener(_markModified);
    _addressController.addListener(_markModified);
    _latitudeController.addListener(_markModified);
    _longitudeController.addListener(_markModified);
  }

  void _markModified() {
    if (!_hasModified) {
      setState(() => _hasModified = true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduleDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _hasModified = true;
    });
  }

  Future<void> _captureLocation() async {
    setState(() => _isLocating = true);
    try {
      final result = await LocationService.instance.getCurrentLocation();
      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _latitudeController.text = result.latitude!.toStringAsFixed(6);
          _longitudeController.text = result.longitude!.toStringAsFixed(6);
          _locationAccuracy = result.accuracy;
          _locationCapturedAt = result.capturedAt;
          _hasModified = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location acquired: ${result.latitude!.toStringAsFixed(5)}, ${result.longitude!.toStringAsFixed(5)}'
              '${result.accuracy != null ? ' (±${result.accuracy!.toStringAsFixed(1)}m)' : ''}',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Failed to get location.'),
            action: result.isPermanentlyDenied
                ? SnackBarAction(label: 'Manual Coords', onPressed: () {})
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _openAddNewCustomer() async {
    final newId = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (context) => const CustomerFormScreen()),
    );

    if (newId != null && mounted) {
      setState(() {
        _selectedCustomerId = newId;
        _hasModified = true;
      });
    }
  }

  Future<void> _handleSave({required bool asDraft}) async {
    // If not draft, run full form validation
    if (!asDraft) {
      if (!_formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please correct the validation errors before scheduling.',
            ),
          ),
        );
        return;
      }

      if (_selectedCustomerId == null || _selectedCustomerId! <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or add a customer.')),
        );
        return;
      }
    } else {
      // Draft at minimum requires a title
      if (_titleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a job title to save as draft.'),
          ),
        );
        return;
      }
    }

    // Validate manual coords if provided
    double? lat;
    double? lng;
    if (_latitudeController.text.trim().isNotEmpty) {
      lat = double.tryParse(_latitudeController.text.trim());
      if (lat == null || !lat.isFinite || lat < -90.0 || lat > 90.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Latitude must be a valid number between -90 and 90.',
            ),
          ),
        );
        return;
      }
    }
    if (_longitudeController.text.trim().isNotEmpty) {
      lng = double.tryParse(_longitudeController.text.trim());
      if (lng == null || !lng.isFinite || lng < -180.0 || lng > 180.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Longitude must be a valid number between -180 and 180.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final targetStatus = asDraft
          ? JobStatus.draft
          : (widget.job == null || widget.job!.status == JobStatus.draft
              ? JobStatus.scheduled
              : widget.job!.status);

      final job = ServiceJob(
        id: widget.job?.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        customerId: _selectedCustomerId ?? 0,
        address: _addressController.text.trim(),
        latitude: lat,
        longitude: lng,
        locationAccuracy: _locationAccuracy,
        locationCapturedAt: _locationCapturedAt ?? (lat != null ? now : null),
        scheduledAt: _scheduledAt,
        priority: _selectedPriority,
        status: targetStatus,
        createdAt: widget.job?.createdAt ?? now,
        updatedAt: now,
        completedAt: widget.job?.completedAt,
      );

      final savedId = await context.read<JobsProvider>().saveJob(job);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.job == null
                ? 'Job #$savedId created successfully.'
                : 'Job #$savedId updated successfully.',
          ),
        ),
      );

      _hasModified = false;
      Navigator.pop(context, savedId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save job: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasModified) return true;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Unsaved Changes?'),
        content: const Text(
          'You have unsaved changes in this job form. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customers = context.watch<JobsProvider>().customers;
    final isEditing = widget.job != null;
    final dateFormat = DateFormat('EEE, MMM d, yyyy • h:mm a');

    return PopScope(
      canPop: !_hasModified,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEditing ? 'Edit Job #${widget.job!.id}' : 'Create New Job',
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Job Title *',
                      hintText: 'e.g. Commercial Refrigerator Quarterly PM',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Job title is required';
                      }
                      if (value.trim().length < 3) {
                        return 'Title must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Customer selection row with Add button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedCustomerId,
                          decoration: const InputDecoration(
                            labelText: 'Customer *',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          hint: const Text('Select existing customer'),
                          items: customers.map((c) {
                            return DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCustomerId = val;
                              _hasModified = true;
                            });
                          },
                          validator: (val) {
                            if (val == null || val <= 0) {
                              return 'Please select a customer';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton.filledTonal(
                          tooltip: 'Add New Customer',
                          onPressed: _openAddNewCustomer,
                          icon: const Icon(Icons.person_add_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Service Address
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Service Address *',
                      hintText: 'e.g. 742 Evergreen Terrace, Suite 100',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Service address is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Scheduled Date & Time
                  InkWell(
                    onTap: _pickScheduleDateTime,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Scheduled Date & Time *',
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(
                        dateFormat.format(_scheduledAt),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Priority Selector
                  Text(
                    'Priority Level',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<JobPriority>(
                    segments: const [
                      ButtonSegment(
                        value: JobPriority.low,
                        label: Text('Low'),
                        icon: Icon(
                          Icons.circle,
                          size: 12,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      ButtonSegment(
                        value: JobPriority.medium,
                        label: Text('Medium'),
                        icon: Icon(
                          Icons.circle,
                          size: 12,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      ButtonSegment(
                        value: JobPriority.high,
                        label: Text('High'),
                        icon: Icon(
                          Icons.circle,
                          size: 12,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                    selected: {_selectedPriority},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _selectedPriority = newSelection.first;
                        _hasModified = true;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Work Scope / Description',
                      hintText:
                          'Describe equipment model, reported issues, or inspection scope...',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Optional GPS Coordinates Section
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
                                    Icons.my_location_rounded,
                                    size: 20,
                                    color: Color(0xFF2563EB),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'GPS Location (Optional)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              if (_isLocating)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                TextButton.icon(
                                  onPressed: _captureLocation,
                                  icon: const Icon(
                                    Icons.gps_fixed_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Acquire GPS'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Capture current coordinates for verification, or enter manually.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _latitudeController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Latitude (-90 to 90)',
                                    hintText: '37.7749',
                                  ),
                                  validator: LocationService.validateLatitude,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _longitudeController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Longitude (-180 to 180)',
                                    hintText: '-122.4194',
                                  ),
                                  validator: LocationService.validateLongitude,
                                ),
                              ),
                            ],
                          ),
                          if (_locationAccuracy != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Captured fix accuracy: ±${_locationAccuracy!.toStringAsFixed(1)}m',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Actions
                  if (!isEditing || _status == JobStatus.draft) ...[
                    ElevatedButton.icon(
                      onPressed:
                          _isSaving ? null : () => _handleSave(asDraft: false),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save & Schedule Job',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed:
                          _isSaving ? null : () => _handleSave(asDraft: true),
                      icon: const Icon(Icons.drafts_outlined),
                      label: const Text('Save as Draft (Incomplete)'),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed:
                          _isSaving ? null : () => _handleSave(asDraft: false),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Update Job Details',
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
