import 'package:flutter/material.dart';

import '../models/checklist_item.dart';

class InspectionItemDialog extends StatefulWidget {
  final ChecklistItem item;
  final bool isReadOnly;

  const InspectionItemDialog({
    super.key,
    required this.item,
    this.isReadOnly = false,
  });

  @override
  State<InspectionItemDialog> createState() => _InspectionItemDialogState();
}

class _InspectionItemDialogState extends State<InspectionItemDialog> {
  late ChecklistResult _selectedResult;
  late TextEditingController _commentController;
  String? _commentError;

  @override
  void initState() {
    super.initState();
    _selectedResult = widget.item.result;
    _commentController = TextEditingController(text: widget.item.comment ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool _validate() {
    final comment = _commentController.text.trim();
    if (_selectedResult == ChecklistResult.fail && comment.isEmpty) {
      setState(() {
        _commentError =
            'A detailed comment is required when marking an item as Fail.';
      });
      return false;
    }

    if (widget.item.isRequired &&
        _selectedResult == ChecklistResult.notApplicable &&
        comment.isEmpty) {
      setState(() {
        _commentError =
            'A justification reason is required when marking a required item as N/A.';
      });
      return false;
    }

    setState(() {
      _commentError = null;
    });
    return true;
  }

  void _handleSave() {
    if (!_validate()) return;

    final updated = widget.item.copyWith(
      result: _selectedResult,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final isRequired = widget.item.isRequired;

    return AlertDialog(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              widget.item.label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          if (isRequired)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Required',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Inspection Result',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),

            // Result Choices
            Wrap(
              spacing: 8,
              children: [
                _buildResultChip(
                  ChecklistResult.pass,
                  'Pass',
                  const Color(0xFF16A34A),
                ),
                _buildResultChip(
                  ChecklistResult.fail,
                  'Fail',
                  const Color(0xFFDC2626),
                ),
                _buildResultChip(
                  ChecklistResult.notApplicable,
                  'N/A',
                  const Color(0xFF475569),
                ),
                _buildResultChip(
                  ChecklistResult.pending,
                  'Pending',
                  const Color(0xFF94A3B8),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Comment Field
            TextField(
              controller: _commentController,
              enabled: !widget.isReadOnly,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _getCommentLabel(),
                hintText: _getCommentHint(),
                errorText: _commentError,
              ),
              onChanged: (_) {
                if (_commentError != null) _validate();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!widget.isReadOnly)
          ElevatedButton(
            onPressed: _handleSave,
            child: const Text('Save Result'),
          ),
      ],
    );
  }

  String _getCommentLabel() {
    if (_selectedResult == ChecklistResult.fail) {
      return 'Failure Reason & Action Taken *';
    }
    if (widget.item.isRequired &&
        _selectedResult == ChecklistResult.notApplicable) {
      return 'Reason for N/A *';
    }
    return 'Comments & Notes (Optional)';
  }

  String _getCommentHint() {
    if (_selectedResult == ChecklistResult.fail) {
      return 'e.g. Broken latch detected. Replacement requested.';
    }
    if (widget.item.isRequired &&
        _selectedResult == ChecklistResult.notApplicable) {
      return 'e.g. Unit has no secondary heating coil fitted.';
    }
    return 'Add any observation details...';
  }

  Widget _buildResultChip(ChecklistResult result, String label, Color color) {
    final isSelected = _selectedResult == result;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? color : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.grey.shade300,
        width: isSelected ? 1.5 : 1.0,
      ),
      onSelected: widget.isReadOnly
          ? null
          : (selected) {
              if (selected) {
                setState(() {
                  _selectedResult = result;
                  _commentError = null;
                });
              }
            },
    );
  }
}
