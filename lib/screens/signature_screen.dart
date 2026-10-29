import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../models/sign_off.dart';
import '../providers/jobs_provider.dart';
import '../services/attachment_service.dart';

class SignatureScreen extends StatefulWidget {
  final int jobId;
  final String? initialSignerName;

  const SignatureScreen({
    super.key,
    required this.jobId,
    this.initialSignerName,
  });

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late SignatureController _signatureController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialSignerName ?? '',
    );
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: const Color(0xFF0F172A),
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  void _handleClear() {
    _signatureController.clear();
  }

  Future<void> _handlePreview() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please draw a signature first to preview.'),
        ),
      );
      return;
    }

    final Uint8List? pngBytes = await _signatureController.toPngBytes();
    if (pngBytes == null || !mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signature Preview'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(pngBytes, height: 140, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            Text(
              'Signer: ${_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : "(No name entered)"}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Signature drawing is empty. Please draw signature on canvas.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    String? savedRelativePath;
    try {
      final Uint8List? pngBytes = await _signatureController.toPngBytes();
      if (pngBytes == null) {
        throw Exception('Failed to generate signature image');
      }

      // Save PNG file to durable app storage
      savedRelativePath = await AttachmentService.instance.saveSignatureBytes(
        bytes: pngBytes,
        jobId: widget.jobId,
      );

      final now = DateTime.now();
      final signOff = SignOff(
        jobId: widget.jobId,
        signerName: _nameController.text.trim(),
        signatureRelativePath: savedRelativePath,
        signedAt: now,
        isCurrent: true,
      );

      if (!mounted) return;
      await context.read<JobsProvider>().saveSignOff(signOff);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer sign-off recorded successfully.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (savedRelativePath != null) {
        // Clean up orphaned signature file on database write failure
        await AttachmentService.instance.deleteFile(savedRelativePath);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save sign-off: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nowFormatted =
        DateFormat('MMMM d, yyyy • h:mm a').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Sign-Off')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Recorded on $nowFormatted',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Signer Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Signer Full Name *',
                    hintText: 'e.g. David Miller (Facility Manager)',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the name of the person signing';
                    }
                    if (value.trim().length < 2) {
                      return 'Signer name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Canvas Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer Signature *',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _handleClear,
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      label: const Text('Clear Canvas'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Canvas Container
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          child: Signature(
                            controller: _signatureController,
                            height: 220,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 16,
                          child: Text(
                            'Sign above the line',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Disclaimer Notice
                Text(
                  'Legal Notice: This on-screen signature captures customer operational acknowledgment that services were performed. It is an internal operational record and does not verify legal identity or provide a certified cryptographic digital signature.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 28),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _handlePreview,
                        icon: const Icon(Icons.preview_rounded),
                        label: const Text('Preview'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _handleConfirm,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Confirm Sign-Off',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
