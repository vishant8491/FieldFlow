class SignOff {
  final int? id;
  final int jobId;
  final String signerName;
  final String signatureRelativePath;
  final DateTime signedAt;
  final bool isCurrent;

  SignOff({
    this.id,
    required this.jobId,
    required this.signerName,
    required this.signatureRelativePath,
    required this.signedAt,
    this.isCurrent = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'signerName': signerName.trim(),
      'signatureRelativePath': signatureRelativePath,
      'signedAt': signedAt.toIso8601String(),
      'isCurrent': isCurrent ? 1 : 0,
    };
  }

  factory SignOff.fromMap(Map<String, dynamic> map) {
    return SignOff(
      id: map['id'] as int?,
      jobId: map['jobId'] as int? ?? 0,
      signerName: map['signerName'] as String? ?? '',
      signatureRelativePath: map['signatureRelativePath'] as String? ?? '',
      signedAt:
          DateTime.tryParse(map['signedAt'] as String? ?? '') ?? DateTime.now(),
      isCurrent: (map['isCurrent'] as int? ?? 1) == 1,
    );
  }

  SignOff copyWith({
    int? id,
    int? jobId,
    String? signerName,
    String? signatureRelativePath,
    DateTime? signedAt,
    bool? isCurrent,
  }) {
    return SignOff(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      signerName: signerName ?? this.signerName,
      signatureRelativePath:
          signatureRelativePath ?? this.signatureRelativePath,
      signedAt: signedAt ?? this.signedAt,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}
