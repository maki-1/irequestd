import 'package:flutter/material.dart';

import 'kiosk_app.dart';
import 'kiosk_flow.dart';
import 'kiosk_review_screen.dart';
import 'kiosk_theme.dart';

/// Step 2: pick one or more documents, each with its own purpose.
class KioskDocumentsScreen extends StatefulWidget {
  const KioskDocumentsScreen({super.key});

  @override
  State<KioskDocumentsScreen> createState() => _KioskDocumentsScreenState();
}

class _KioskDocumentsScreenState extends State<KioskDocumentsScreen> {
  // Copied from lib/request_document_screen.dart so the kiosk tree stays
  // independent of the phone-app screens.
  static const _docTypes = [
    'Barangay Clearance',
    'Certificate of Residency',
    'Certificate of Indigency',
  ];
  static const _purposes = [
    'Employment',
    'Travel',
    'Bank Requirements',
    'Scholarship',
    'Government Assistance',
    'Other',
  ];
  static const _docIcons = {
    'Barangay Clearance': Icons.assignment_outlined,
    'Certificate of Residency': Icons.home_outlined,
    'Certificate of Indigency': Icons.badge_outlined,
  };

  // docType -> chosen purpose (null = selected but no purpose yet).
  final Map<String, String?> _picked = {};

  @override
  void initState() {
    super.initState();
    for (final s in kioskFlow.selections) {
      _picked[s.documentType] = s.purpose.isEmpty ? null : s.purpose;
    }
  }

  bool get _canReview =>
      _picked.isNotEmpty && _picked.values.every((p) => p != null && p.isNotEmpty);

  void _toReview() {
    kioskFlow.selections
      ..clear()
      ..addAll(_picked.entries.map((e) => DocSelection(e.key, e.value!)));
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const KioskReviewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: KioskColors.green,
        foregroundColor: Colors.white,
        title: const Text('Choose your documents'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _identityHeader(),
                  const SizedBox(height: 20),
                  const Text('Select the documents you need:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ..._docTypes.map(_docCard),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 72,
                    child: ElevatedButton(
                      onPressed: _canReview ? _toReview : null,
                      child: const Text('Review'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF4EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KioskColors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_circle_outlined, color: KioskColors.green, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Requesting as',
                    style: TextStyle(fontSize: 13, color: Colors.black54)),
                Text(
                  kioskFlow.fullName.isEmpty ? '—' : kioskFlow.fullName,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${kioskFlow.purok} · Clearance ${kioskFlow.controlNo}',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: kioskReturnToIdle,
            child: const Text('Not you?'),
          ),
        ],
      ),
    );
  }

  Widget _docCard(String type) {
    final selected = _picked.containsKey(type);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEDF4EC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? KioskColors.green : Colors.black12,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (selected) {
                _picked.remove(type);
              } else {
                _picked[type] = null;
              }
            }),
            child: Row(
              children: [
                Icon(_docIcons[type], color: selected ? KioskColors.green : Colors.black38, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(type,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: selected ? KioskColors.green : Colors.black87)),
                ),
                Icon(
                  selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  color: selected ? KioskColors.green : Colors.black26,
                  size: 26,
                ),
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _picked[type],
              isExpanded: true,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Purpose of this document',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _purposes
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _picked[type] = v),
            ),
          ],
        ],
      ),
    );
  }
}
