import 'package:flutter/material.dart';

class CompletionBlockersDialog extends StatelessWidget {
  final List<String> blockers;

  const CompletionBlockersDialog({super.key, required this.blockers});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
          SizedBox(width: 8),
          Text('Completion Blockers'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The following requirements must be resolved before this job can be marked completed:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...blockers.map(
              (blocker) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                        fontSize: 14,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        blocker,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Understood'),
        ),
      ],
    );
  }
}
