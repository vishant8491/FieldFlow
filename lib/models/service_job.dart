import 'package:flutter/material.dart';

enum JobPriority {
  low,
  medium,
  high;

  String get displayName {
    switch (this) {
      case JobPriority.low:
        return 'Low';
      case JobPriority.medium:
        return 'Medium';
      case JobPriority.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case JobPriority.low:
        return const Color(0xFF10B981); // Emerald green
      case JobPriority.medium:
        return const Color(0xFFF59E0B); // Amber
      case JobPriority.high:
        return const Color(0xFFEF4444); // Red
    }
  }

  static JobPriority fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'low':
        return JobPriority.low;
      case 'high':
        return JobPriority.high;
      case 'medium':
      default:
        return JobPriority.medium;
    }
  }
}

enum JobStatus {
  draft,
  scheduled,
  inProgress,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case JobStatus.draft:
        return 'Draft';
      case JobStatus.scheduled:
        return 'Scheduled';
      case JobStatus.inProgress:
        return 'In Progress';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case JobStatus.draft:
        return const Color(0xFF64748B); // Slate gray
      case JobStatus.scheduled:
        return const Color(0xFF2563EB); // Cobalt blue
      case JobStatus.inProgress:
        return const Color(0xFFD97706); // Restrained amber
      case JobStatus.completed:
        return const Color(0xFF059669); // Forest green
      case JobStatus.cancelled:
        return const Color(0xFFDC2626); // Crimson red
    }
  }

  static JobStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'scheduled':
        return JobStatus.scheduled;
      case 'inprogress':
      case 'in_progress':
        return JobStatus.inProgress;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
      case 'canceled':
        return JobStatus.cancelled;
      case 'draft':
      default:
        return JobStatus.draft;
    }
  }
}

class ServiceJob {
  final int? id;
  final String title;
  final String description;
  final int customerId;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracy;
  final DateTime? locationCapturedAt;
  final DateTime scheduledAt;
  final JobPriority priority;
  final JobStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  ServiceJob({
    this.id,
    required this.title,
    required this.description,
    required this.customerId,
    required this.address,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    this.locationCapturedAt,
    required this.scheduledAt,
    this.priority = JobPriority.medium,
    this.status = JobStatus.draft,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  bool get isCompleted => status == JobStatus.completed;
  bool get isCancelled => status == JobStatus.cancelled;
  bool get isReadOnly => isCompleted || isCancelled;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title.trim(),
      'description': description.trim(),
      'customerId': customerId,
      'address': address.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'locationAccuracy': locationAccuracy,
      'locationCapturedAt': locationCapturedAt?.toIso8601String(),
      'scheduledAt': scheduledAt.toIso8601String(),
      'priority': priority.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory ServiceJob.fromMap(Map<String, dynamic> map) {
    return ServiceJob(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      customerId: map['customerId'] as int? ?? 0,
      address: map['address'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationAccuracy: (map['locationAccuracy'] as num?)?.toDouble(),
      locationCapturedAt: map['locationCapturedAt'] != null
          ? DateTime.tryParse(map['locationCapturedAt'] as String)
          : null,
      scheduledAt: DateTime.tryParse(map['scheduledAt'] as String? ?? '') ??
          DateTime.now(),
      priority: JobPriority.fromString(map['priority'] as String?),
      status: JobStatus.fromString(map['status'] as String?),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
    );
  }

  ServiceJob copyWith({
    int? id,
    String? title,
    String? description,
    int? customerId,
    String? address,
    double? latitude,
    double? longitude,
    double? locationAccuracy,
    DateTime? locationCapturedAt,
    DateTime? scheduledAt,
    JobPriority? priority,
    JobStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return ServiceJob(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      customerId: customerId ?? this.customerId,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      locationCapturedAt: locationCapturedAt ?? this.locationCapturedAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
