import 'package:flutter/material.dart';

enum ChecklistResult {
  pending,
  pass,
  fail,
  notApplicable;

  String get displayName {
    switch (this) {
      case ChecklistResult.pending:
        return 'Pending';
      case ChecklistResult.pass:
        return 'Pass';
      case ChecklistResult.fail:
        return 'Fail';
      case ChecklistResult.notApplicable:
        return 'N/A';
    }
  }

  Color get color {
    switch (this) {
      case ChecklistResult.pending:
        return const Color(0xFF94A3B8); // Slate 400
      case ChecklistResult.pass:
        return const Color(0xFF16A34A); // Green 600
      case ChecklistResult.fail:
        return const Color(0xFFDC2626); // Red 600
      case ChecklistResult.notApplicable:
        return const Color(0xFF475569); // Slate 600
    }
  }

  static ChecklistResult fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pass':
        return ChecklistResult.pass;
      case 'fail':
        return ChecklistResult.fail;
      case 'notapplicable':
      case 'not_applicable':
      case 'na':
        return ChecklistResult.notApplicable;
      case 'pending':
      default:
        return ChecklistResult.pending;
    }
  }
}

class ChecklistItem {
  final int? id;
  final int jobId;
  final String label;
  final bool isRequired;
  final int sortOrder;
  final ChecklistResult result;
  final String? comment;

  ChecklistItem({
    this.id,
    required this.jobId,
    required this.label,
    this.isRequired = true,
    this.sortOrder = 0,
    this.result = ChecklistResult.pending,
    this.comment,
  });

  bool get isAssessed => result != ChecklistResult.pending;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'label': label.trim(),
      'isRequired': isRequired ? 1 : 0,
      'sortOrder': sortOrder,
      'result': result.name,
      'comment': comment?.trim().isEmpty == true ? null : comment?.trim(),
    };
  }

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'] as int?,
      jobId: map['jobId'] as int? ?? 0,
      label: map['label'] as String? ?? '',
      isRequired: (map['isRequired'] as int? ?? 1) == 1,
      sortOrder: map['sortOrder'] as int? ?? 0,
      result: ChecklistResult.fromString(map['result'] as String?),
      comment: map['comment'] as String?,
    );
  }

  ChecklistItem copyWith({
    int? id,
    int? jobId,
    String? label,
    bool? isRequired,
    int? sortOrder,
    ChecklistResult? result,
    String? comment,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      label: label ?? this.label,
      isRequired: isRequired ?? this.isRequired,
      sortOrder: sortOrder ?? this.sortOrder,
      result: result ?? this.result,
      comment: comment ?? this.comment,
    );
  }
}
