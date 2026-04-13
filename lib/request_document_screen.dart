import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
  static const double _pricePhp = 5.0;

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

  bool get _canProceed =>
      _docType != null && _purpose != null && _deliveryMethod != null;

  // Shows payment bottom sheet — user confirms then pays via PayMongo
  void _showPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(
        documentType: _docType!,
        purpose: _purpose!,
        additionalDetails: _detailsController.text.trim(),
        deliveryMethod: _deliveryMethod!,
        pricePhp: _pricePhp,
        onPaid: () {
          Navigator.pop(context); // close sheet
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
          );
        },
      ),
    );
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
            const SizedBox(height: 24),

            // Price summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black08),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Processing fee',
                      style: TextStyle(fontSize: 14, color: Colors.black54)),
                  Text(
                    '₱${_pricePhp.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A6B1A)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: (_canProceed && !_isLoading) ? _showPaymentSheet : null,
                icon: const Icon(Icons.payment_rounded),
                label: const Text('Proceed to Payment  ₱5.00',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
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
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
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

// ─────────────────────────────────────────────────────────────────────────────
// Payment bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

enum _PayState { idle, creatingLink, awaitingPayment, polling, paid, error }

class _PaymentSheet extends StatefulWidget {
  final String documentType;
  final String purpose;
  final String additionalDetails;
  final String deliveryMethod;
  final double pricePhp;
  final VoidCallback onPaid;

  const _PaymentSheet({
    required this.documentType,
    required this.purpose,
    required this.additionalDetails,
    required this.deliveryMethod,
    required this.pricePhp,
    required this.onPaid,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _lime = Color(0xFF4CFF4C);

  _PayState _state = _PayState.idle;
  String? _linkId;
  String? _checkoutUrl;
  String? _errorMsg;
  Timer? _pollTimer;
  int _pollCount = 0;
  static const _maxPolls = 40; // 40 × 5s = ~3 min timeout

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createLinkAndPay() async {
    setState(() { _state = _PayState.creatingLink; _errorMsg = null; });

    try {
      final result = await ApiService.createPaymentLink(
        documentType: widget.documentType,
        purpose: widget.purpose,
        additionalDetails: widget.additionalDetails,
        deliveryMethod: widget.deliveryMethod,
      );

      if (result['statusCode'] != 201) {
        setState(() {
          _state = _PayState.error;
          _errorMsg = result['message'] as String? ?? 'Failed to create payment link';
        });
        return;
      }

      _linkId = result['linkId'] as String;
      _checkoutUrl = result['checkoutUrl'] as String;

      // Open PayMongo checkout in browser
      final uri = Uri.parse(_checkoutUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      setState(() { _state = _PayState.awaitingPayment; });
      _startPolling();
    } catch (_) {
      setState(() {
        _state = _PayState.error;
        _errorMsg = 'Connection error. Please try again.';
      });
    }
  }

  void _startPolling() {
    _pollCount = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      _pollCount++;
      if (_pollCount > _maxPolls) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() {
            _state = _PayState.error;
            _errorMsg = 'Payment timed out. If you already paid, it will reflect shortly.';
          });
        }
        return;
      }

      setState(() => _state = _PayState.polling);
      try {
        final status = await ApiService.checkPaymentStatus(_linkId!);
        if (status['paid'] == true) {
          _pollTimer?.cancel();
          if (mounted) setState(() => _state = _PayState.paid);
          await Future.delayed(const Duration(milliseconds: 1200));
          if (mounted) widget.onPaid();
        } else {
          if (mounted) setState(() => _state = _PayState.awaitingPayment);
        }
      } catch (_) {
        if (mounted) setState(() => _state = _PayState.awaitingPayment);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.black12, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Payment Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 16),

          // Order details
          _summaryRow(Icons.description_outlined, 'Document', widget.documentType),
          _summaryRow(Icons.info_outline_rounded, 'Purpose', widget.purpose),
          _summaryRow(
            widget.deliveryMethod.contains('Email')
                ? Icons.email_outlined
                : Icons.store_outlined,
            'Delivery',
            widget.deliveryMethod,
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Processing fee',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
              Text(
                '₱${widget.pricePhp.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A6B1A)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // State-driven content
          _buildStateContent(),
          const SizedBox(height: 8),

          // PayMongo badge
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline_rounded, size: 12, color: Colors.black38),
                SizedBox(width: 4),
                Text('Secured by PayMongo',
                    style: TextStyle(fontSize: 11, color: Colors.black38)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateContent() {
    switch (_state) {
      case _PayState.idle:
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _createLinkAndPay,
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text('Pay ₱5.00 via PayMongo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            ),
          ),
        );

      case _PayState.creatingLink:
        return const _StatusTile(
          icon: Icons.hourglass_top_rounded,
          color: Colors.orange,
          title: 'Creating payment link…',
          subtitle: 'Please wait',
        );

      case _PayState.awaitingPayment:
      case _PayState.polling:
        return Column(
          children: [
            const _StatusTile(
              icon: Icons.open_in_browser_rounded,
              color: Color(0xFF1A6B1A),
              title: 'Complete payment in your browser',
              subtitle: 'Waiting for confirmation…',
              showSpinner: true,
            ),
            const SizedBox(height: 12),
            // Manual reopen link
            if (_checkoutUrl != null)
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(_checkoutUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reopen payment page'),
                style: TextButton.styleFrom(foregroundColor: _green),
              ),
          ],
        );

      case _PayState.paid:
        return const _StatusTile(
          icon: Icons.check_circle_rounded,
          color: Color(0xFF4CFF4C),
          title: 'Payment confirmed!',
          subtitle: 'Redirecting to your requests…',
        );

      case _PayState.error:
        return Column(
          children: [
            _StatusTile(
              icon: Icons.error_outline_rounded,
              color: Colors.redAccent,
              title: 'Something went wrong',
              subtitle: _errorMsg ?? 'Please try again.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => setState(() {
                  _state = _PayState.idle;
                  _errorMsg = null;
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        );
    }
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.black38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.black38)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status tile widget ────────────────────────────────────────────────────────

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool showSpinner;

  const _StatusTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          showSpinner
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: color),
                )
              : Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
