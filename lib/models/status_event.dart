import 'service_job.dart';

class StatusEvent {
  final int? id;
  final int jobId;
  final JobStatus? previousStatus;
  final JobStatus nextStatus;
  final String? reason;
  final DateTime timestamp;

  StatusEvent({
    this.id,
    required this.jobId,
    this.previousStatus,
    required this.nextStatus,
    this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'previousStatus': previousStatus?.name,
      'nextStatus': nextStatus.name,
      'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory StatusEvent.fromMap(Map<String, dynamic> map) {
    return StatusEvent(
      id: map['id'] as int?,
      jobId: map['jobId'] as int? ?? 0,
      previousStatus: map['previousStatus'] != null
          ? JobStatus.fromString(map['previousStatus'] as String)
          : null,
      nextStatus: JobStatus.fromString(map['nextStatus'] as String?),
      reason: map['reason'] as String?,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
