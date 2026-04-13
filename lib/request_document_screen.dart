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
  static const Color _limeGreen = Color(0xFF4CFF4C);

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

  static const _deliveryMethods = [
    'Pick up at Barangay Office',
    'Digital (Email)',
  ];

  static const _docIcons = {
    'Barangay Clearance': Icons.assignment_outlined,
    'Certificate of Residency': Icons.home_outlined,
    'Certificate of Indigency': Icons.badge_outlined,
  };

  String? _docType;
  String? _purpose;
  String? _deliveryMethod;
  final _detailsController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _docType = widget.preselectedType;
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _docType != null && _purpose != null && _deliveryMethod != null;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.createRequest(
        documentType: _docType!,
        purpose: _purpose!,
        additionalDetails: _detailsController.text.trim(),
        deliveryMethod: _deliveryMethod!,
      );
      if (!mounted) return;
      if (result['statusCode'] == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request submitted successfully!'),
          backgroundColor: Color(0xFF1A6B1A),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
        );
      } else {
        _showError(result['message'] as String? ?? 'Submission failed');
      }
    } catch (_) {
      if (mounted) _showError('Connection error. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
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
            _sectionLabel('Select Document Type *'),
            const SizedBox(height: 8),
            ..._docTypes.map((type) => _radioCard(
                  value: type,
                  groupValue: _docType,
                  icon: _docIcons[type] ?? Icons.description_outlined,
                  onChanged: (v) => setState(() => _docType = v),
                )),
            const SizedBox(height: 20),

            _sectionLabel('Purpose of Document *'),
            const SizedBox(height: 8),
            _dropdown(
              value: _purpose,
              hint: 'Select purpose',
              items: _purposes,
              onChanged: (v) => setState(() => _purpose = v),
            ),
            const SizedBox(height: 20),

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

            _sectionLabel('Delivery Method *'),
            const SizedBox(height: 8),
            ..._deliveryMethods.map((m) => _radioCard(
                  value: m,
                  groupValue: _deliveryMethod,
                  icon: m.contains('Email')
                      ? Icons.email_outlined
                      : Icons.store_outlined,
                  onChanged: (v) => setState(() => _deliveryMethod = v),
                )),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_canSubmit && !_isLoading) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSubmit ? _green : Colors.black12,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.black12,
                  disabledForegroundColor: Colors.black38,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Submit Request',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87),
      );

  Widget _radioCard({
    required String value,
    required String? groupValue,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    final selected = groupValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _green : Colors.black12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _green : Colors.black38, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? _green : Colors.black87)),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? _green : Colors.black26,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

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
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87),
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
                child: Text(e,
                    style: const TextStyle(color: Colors.black87)),
              ))
          .toList(),
    );
  }
}
