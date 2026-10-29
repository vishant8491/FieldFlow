import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/checklist_template.dart';
import '../models/template_item.dart';
import '../providers/jobs_provider.dart';

class TemplateFormScreen extends StatefulWidget {
  final ChecklistTemplate? template;

  const TemplateFormScreen({super.key, this.template});

  @override
  State<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<TemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  final List<TemplateItem> _items = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final tpl = widget.template;
    _nameController = TextEditingController(text: tpl?.name ?? '');
    _descController = TextEditingController(text: tpl?.description ?? '');
    if (tpl != null) {
      _items.addAll(tpl.items);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _addItemDialog({TemplateItem? existingItem, int? index}) {
    final labelController = TextEditingController(
      text: existingItem?.label ?? '',
    );
    bool isRequired = existingItem?.isRequired ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            existingItem == null ? 'Add Checklist Item' : 'Edit Item',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Checklist Task / Verification *',
                  hintText: 'e.g. Test emergency shut-off switch',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Required check before job completion'),
                value: isRequired,
                onChanged: (val) => setModalState(() => isRequired = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (labelController.text.trim().isEmpty) return;
                setState(() {
                  if (existingItem != null && index != null) {
                    _items[index] = existingItem.copyWith(
                      label: labelController.text.trim(),
                      isRequired: isRequired,
                    );
                  } else {
                    _items.add(
                      TemplateItem(
                        templateId: widget.template?.id ?? 0,
                        label: labelController.text.trim(),
                        isRequired: isRequired,
                        sortOrder: _items.length,
                      ),
                    );
                  }
                });
                Navigator.pop(context);
              },
              child: Text(existingItem == null ? 'Add Item' : 'Save Item'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add at least one item to this checklist template.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final tpl = ChecklistTemplate(
        id: widget.template?.id,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        createdAt: widget.template?.createdAt ?? now,
        items: _items,
      );

      final provider = context.read<JobsProvider>();
      await provider.saveTemplate(tpl, _items);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.template == null
                ? 'Template created successfully.'
                : 'Template updated successfully.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save template: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.template != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Template' : 'New Checklist Template'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Save Template',
            onPressed: _isSaving ? null : _handleSave,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Details Form
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Template Name *',
                        hintText: 'e.g. Commercial Refrigerator Inspection',
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Template name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Purpose of this checklist...',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Items List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Template Items (${_items.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addItemDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Item'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Reorderable list of items
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                      child: Text(
                        'No checklist items yet.\nTap "+ Add Item" to define tasks.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: _items.length,
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final item = _items.removeAt(oldIndex);
                          _items.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          key: ValueKey('tpl_item_${index}_${item.label}'),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: item.isRequired
                                    ? const Color(0xFFEF4444)
                                        .withValues(alpha: 0.1)
                                    : const Color(0xFF64748B)
                                        .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.isRequired
                                    ? Icons.priority_high_rounded
                                    : Icons.check_rounded,
                                size: 16,
                                color: item.isRequired
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            title: Text(
                              item.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              item.isRequired ? 'Required' : 'Optional',
                              style: TextStyle(
                                fontSize: 11,
                                color: item.isRequired
                                    ? const Color(0xFFDC2626)
                                    : Colors.grey,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () => _addItemDialog(
                                    existingItem: item,
                                    index: index,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() => _items.removeAt(index));
                                  },
                                ),
                                const Icon(
                                  Icons.drag_handle_rounded,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
