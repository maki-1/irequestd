import 'package:flutter/material.dart';

import 'kiosk_api.dart';
import 'kiosk_app.dart';
import 'kiosk_success_screen.dart';
import 'kiosk_theme.dart';

/// Step 3: confirm and submit. One clearance is spent on this whole submission.
class KioskReviewScreen extends StatefulWidget {
  const KioskReviewScreen({super.key});

  @override
  State<KioskReviewScreen> createState() => _KioskReviewScreenState();
}

class _KioskReviewScreenState extends State<KioskReviewScreen> {
  bool _loading = false;
  String? _error;
  Map<String, double> _prices = {};
  bool _loadingPrices = true;

  @override
  void initState() {
    super.initState();
    KioskApi.fetchDocumentPrices().then((prices) {
      if (mounted) setState(() { _prices = prices; _loadingPrices = false; });
    });
  }

  double get _totalDue => kioskFlow.selections
      .fold(0.0, (sum, s) => sum + (_prices[s.documentType] ?? 0));

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await KioskApi.submitRequests(
        controlNo: kioskFlow.controlNo,
        surname: kioskFlow.surname,
        items: kioskFlow.toItems(),
      );
      if (!mounted) return;
      if (res['statusCode'] == 201 && res['ok'] == true) {
        final requests = (res['requests'] as List?) ?? const [];
        final orNumbers = requests
            .map((r) => (r as Map)['orNumber'] as String?)
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toList();
        // Server-computed and authoritative — what's actually owed for these
        // documents, separate from the purok clearance fee already settled.
        final totalDue = (res['totalDue'] as num?)?.toDouble() ?? _totalDue;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => KioskSuccessScreen(
              controlNo: res['controlNo'] as String? ?? kioskFlow.controlNo,
              orNumbers: orNumbers,
              totalDue: totalDue,
            ),
          ),
        );
      } else {
        setState(() => _error = res['message'] as String? ??
            'We could not submit your request. Please try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Connection problem. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: KioskColors.green,
        foregroundColor: Colors.white,
        title: const Text('Review your request'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kioskFlow.fullName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('${kioskFlow.purok} · Clearance ${kioskFlow.controlNo}',
                      style: const TextStyle(fontSize: 15, color: Colors.black54)),
                  const SizedBox(height: 20),
                  ...kioskFlow.selections.map(
                    (s) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined, color: KioskColors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.documentType,
                                    style: const TextStyle(
                                        fontSize: 17, fontWeight: FontWeight.w700)),
                                Text('Purpose: ${s.purpose}',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black54)),
                              ],
                            ),
                          ),
                          if (!_loadingPrices && (_prices[s.documentType] ?? 0) > 0)
                            Text('₱${_prices[s.documentType]!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF4EC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your purok clearance already covers its own fee — these '
                          'documents are approved on submission, no waiting for the '
                          'Purok Leader.',
                          style: TextStyle(fontSize: 15, color: KioskColors.green, height: 1.4),
                        ),
                        if (!_loadingPrices && _totalDue > 0) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0x330B3D2E)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Amount to pay at the Collector',
                                  style: TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w700, color: KioskColors.green)),
                              Text('₱${_totalDue.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.w800, color: KioskColors.green)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'This is the document fee, separate from your purok clearance. '
                            'Pay it in cash at the Collector\'s counter before claiming.',
                            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: KioskColors.danger),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: KioskColors.danger, fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: kioskReturnToIdle,
                      child: const Text('Start over'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 76,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3, color: Colors.white))
                          : const Icon(Icons.check_circle_outline, size: 28),
                      label: Text(_loading ? 'Submitting…' : 'Submit request'),
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
}
