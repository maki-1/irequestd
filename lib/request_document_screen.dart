import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'my_requests_screen.dart';

class RequestDocumentScreen extends StatefulWidget {
  final String? preselectedType;
  const RequestDocumentScreen({super.key, this.preselectedType});

  @override
  State<RequestDocumentScreen> createState() => _RequestDocumentScreenState();
}

class _RequestDocumentScreenState extends State<RequestDocumentScreen> {
  static const Color _green = Color(0xFF1A6B1A);

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

  final Set<String> _selectedDocs = {};
  String? _purpose;
  final _detailsController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedType != null) {
      _selectedDocs.add(widget.preselectedType!);
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  bool get _canProceed => _selectedDocs.isNotEmpty && _purpose != null;

  List<Map<String, String>> get _items => _selectedDocs.map((doc) => {
        'documentType': doc,
        'purpose': _purpose!,
        'additionalDetails': _detailsController.text.trim(),
        'deliveryMethod': 'Pick up at Barangay Office',
      }).toList();

  Future<void> _submitRequest() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.createBulkRequest(items: _items);
      if (!mounted) return;
      if (result['statusCode'] == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted! Awaiting Purok Leader approval.'),
            backgroundColor: Color(0xFF1A6B1A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Failed to submit request'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection error. Please try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _detailsController.text.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Request Document',
            style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ───────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A6B1A).withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF1A6B1A)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'After submitting, your request will be reviewed by the Purok Leader. '
                      'You will be notified to pay once it is approved.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF1A6B1A), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Document selection ────────────────────────────────────
            _sectionLabel('Select Document(s) *'),
            const SizedBox(height: 8),
            ..._docTypes.map((type) => _checkCard(
                  label: type,
                  icon: _docIcons[type] ?? Icons.description_outlined,
                  checked: _selectedDocs.contains(type),
                  onChanged: (checked) => setState(() {
                    if (checked) {
                      _selectedDocs.add(type);
                    } else {
                      _selectedDocs.remove(type);
                    }
                  }),
                )),
            const SizedBox(height: 20),

            // ── Purpose ───────────────────────────────────────────────
            _sectionLabel('Purpose of Document *'),
            const SizedBox(height: 8),
            _dropdown(
              value: _purpose,
              hint: 'Select purpose',
              items: _purposes,
              onChanged: (v) => setState(() => _purpose = v),
            ),
            const SizedBox(height: 20),

            // ── Additional Details ────────────────────────────────────
            _sectionLabel('Additional Details'),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 4,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Any additional information...',
                hintStyle:
                    const TextStyle(color: Colors.black38, fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                counterText: '$charCount / 500',
                counterStyle:
                    const TextStyle(color: Colors.black38, fontSize: 11),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // ── Submit button ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: (_canProceed && !_isLoading) ? _submitRequest : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  'Submit Request${_selectedDocs.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canProceed ? _green : Colors.black12,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.black12,
                  disabledForegroundColor: Colors.black38,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _checkCard({
    required String label,
    required IconData icon,
    required bool checked,
    required void Function(bool) onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!checked),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: checked ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: checked ? _green : Colors.black12,
            width: checked ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: checked ? _green : Colors.black38, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: checked ? _green : Colors.black87)),
            ),
            Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: checked ? _green : Colors.black26,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
      );

  Widget _dropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      dropdownColor: Colors.white,
      isExpanded: true,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      ),
      items: items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(color: Colors.black87)),
              ))
          .toList(),
    );
  }
}
