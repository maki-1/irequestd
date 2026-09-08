import 'package:flutter/material.dart';

import 'kiosk_api.dart';
import 'kiosk_app.dart';
import 'kiosk_documents_screen.dart';
import 'kiosk_theme.dart';

/// Step 1: the resident types the control number from their printed purok
/// clearance and their surname (a second factor, so a found or guessed slip
/// alone gets nowhere).
class KioskClearanceScreen extends StatefulWidget {
  const KioskClearanceScreen({super.key});

  @override
  State<KioskClearanceScreen> createState() => _KioskClearanceScreenState();
}

class _KioskClearanceScreenState extends State<KioskClearanceScreen> {
  // Matches ALPHABET in backend lib/purokClearance.js — no 0/O, 1/I/L, U.
  static const String _alphabet = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const int _codeLen = 6;

  String _code = '';
  final _surnameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _surnameCtrl.dispose();
    super.dispose();
  }

  void _tap(String ch) {
    if (_code.length < _codeLen) {
      setState(() {
        _code += ch;
        _error = null;
      });
    }
  }

  void _backspace() {
    if (_code.isNotEmpty) {
      setState(() => _code = _code.substring(0, _code.length - 1));
    }
  }

  bool get _ready =>
      _code.length == _codeLen && _surnameCtrl.text.trim().isNotEmpty && !_loading;

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await KioskApi.verifyClearance(
        controlNo: 'PC-$_code',
        surname: _surnameCtrl.text,
      );
      if (!mounted) return;
      if (res['statusCode'] == 200 && res['ok'] == true) {
        final c = (res['clearance'] as Map).cast<String, dynamic>();
        kioskFlow
          ..controlNo = c['controlNo'] as String? ?? 'PC-$_code'
          ..surname = _surnameCtrl.text.trim()
          ..fullName = c['fullName'] as String? ?? ''
          ..purok = c['purok'] as String? ?? '';
        kioskFlow.selections.clear();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const KioskDocumentsScreen()),
        );
      } else {
        setState(() => _error =
            res['message'] as String? ?? 'We could not verify that clearance.');
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
        title: const Text('Enter your control number'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Text(
                    'Type the control number printed on your purok clearance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  _codeDisplay(),
                  const SizedBox(height: 20),
                  _keypad(),
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Your surname',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black.withValues(alpha: 0.8))),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _surnameCtrl,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                      hintText: 'As written on your slip',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
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
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 72,
                    child: ElevatedButton(
                      onPressed: _ready ? _verify : null,
                      child: _loading
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3, color: Colors.white))
                          : const Text('Continue'),
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

  Widget _codeDisplay() {
    Widget slot(int i) {
      final filled = i < _code.length;
      return Container(
        width: 52,
        height: 66,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? KioskColors.green : Colors.black26,
            width: filled ? 2 : 1,
          ),
        ),
        child: Text(
          filled ? _code[i] : '',
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('PC-',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        for (var i = 0; i < 4; i++) ...[slot(i), const SizedBox(width: 6)],
        const Text('-', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        for (var i = 4; i < 6; i++) ...[slot(i), const SizedBox(width: 6)],
      ],
    );
  }

  Widget _keypad() {
    final keys = _alphabet.split('');
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final k in keys)
              SizedBox(
                width: 58,
                height: 58,
                child: OutlinedButton(
                  onPressed: _code.length < _codeLen ? () => _tap(k) : null,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black26),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(k,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                ),
              ),
            SizedBox(
              width: 58,
              height: 58,
              child: OutlinedButton(
                onPressed: _code.isNotEmpty ? _backspace : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.backspace_outlined, color: Colors.black87),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
