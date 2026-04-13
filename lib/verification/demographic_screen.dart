import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'step_progress_bar.dart';
import 'education_screen.dart';

class DemographicScreen extends StatefulWidget {
  const DemographicScreen({super.key});

  @override
  State<DemographicScreen> createState() => _DemographicScreenState();
}

class _DemographicScreenState extends State<DemographicScreen> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _limeGreen = Color(0xFF4CFF4C);

  static const _psgcBase = 'https://psgc.gitlab.io/api';

  // PSGC codes
  static const _bukidnonCode = '101300000';
  static const _maramagCode = '101302000';

  // Hardcoded Dologon puroks (PSGC has no purok-level data)
  static const _dologonPuroks = [
    'Purok 1',
    'Purok 2',
    'Purok 3',
    'Purok 4',
    'Purok 5',
    'Purok 6',
    'Purok 7',
    'Purok 8',
    'Purok 9',
    'Purok 10',
  ];

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _houseStreetController = TextEditingController();
  final _ageController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _fatherNameController = TextEditingController();

  String? _gender;
  String? _yearsAtAddress;
  bool _isLoading = false;
  bool _agreedToTerms = false;

  // Location state
  List<Map<String, String>> _municipalities = [];
  List<Map<String, String>> _barangays = [];

  // Province is defaulted to Bukidnon (fixed display name; code used for API)
  static const _provinceName = 'Bukidnon';

  String? _selectedMunicipalityCode;
  String? _selectedMunicipalityName;
  String? _selectedBarangay;
  String? _selectedPurok;

  bool _loadingMunicipalities = false;
  bool _loadingBarangays = false;

  static const _genders = ['Male', 'Female', 'Other'];
  static const _yearsOptions = [
    '6 months - 1 year',
    '1 - 3 years',
    '3 - 5 years',
    '5+ years',
  ];

  @override
  void initState() {
    super.initState();
    _loadMunicipalities(_bukidnonCode);
  }

  Future<void> _loadMunicipalities(String provinceCode) async {
    setState(() {
      _loadingMunicipalities = true;
      _municipalities = [];
      _selectedMunicipalityCode = null;
      _selectedMunicipalityName = null;
      _barangays = [];
      _selectedBarangay = null;
      _selectedPurok = null;
    });
    try {
      final res = await http.get(
        Uri.parse('$_psgcBase/provinces/$provinceCode/municipalities/'),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body) as List;
        final list = data
            .map<Map<String, String>>((e) => {
                  'code': e['code'].toString(),
                  'name': e['name'].toString(),
                })
            .toList()
          ..sort((a, b) => a['name']!.compareTo(b['name']!));
        if (mounted) {
          setState(() {
            _municipalities = list;
            _loadingMunicipalities = false;
          });
          // Default to Maramag
          final maramag = list.firstWhere(
            (m) => m['code'] == _maramagCode,
            orElse: () => {},
          );
          if (maramag.isNotEmpty) {
            await _loadBarangays(maramag['code']!, maramag['name']!);
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMunicipalities = false);
    }
  }

  Future<void> _loadBarangays(String municipalityCode, String municipalityName) async {
    setState(() {
      _selectedMunicipalityCode = municipalityCode;
      _selectedMunicipalityName = municipalityName;
      _barangays = [];
      _selectedBarangay = null;
      _selectedPurok = null;
      _loadingBarangays = true;
    });
    try {
      final res = await http.get(
        Uri.parse('$_psgcBase/municipalities/$municipalityCode/barangays/'),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body) as List;
        final list = data
            .map<Map<String, String>>((e) => {
                  'code': e['code'].toString(),
                  'name': e['name'].toString(),
                })
            .toList()
          ..sort((a, b) => a['name']!.compareTo(b['name']!));
        if (mounted) {
          setState(() {
            _barangays = list;
            _loadingBarangays = false;
            // Default to Dologon when Maramag is selected
            if (municipalityCode == _maramagCode) {
              final dologon = list.firstWhere(
                (b) => b['name']!.toUpperCase().contains('DOLOGON'),
                orElse: () => {},
              );
              if (dologon.isNotEmpty) _selectedBarangay = dologon['name'];
            }
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBarangays = false);
    }
  }

  bool get _isDologon =>
      _selectedBarangay != null &&
      _selectedBarangay!.toUpperCase().contains('DOLOGON');

  @override
  void dispose() {
    _fullNameController.dispose();
    _houseStreetController.dispose();
    _ageController.dispose();
    _motherNameController.dispose();
    _fatherNameController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final parts = <String>[
      if (_selectedPurok != null) _selectedPurok!,
      if (_houseStreetController.text.trim().isNotEmpty)
        _houseStreetController.text.trim(),
      if (_selectedBarangay != null) 'Brgy. $_selectedBarangay',
      if (_selectedMunicipalityName != null) _selectedMunicipalityName!,
      _provinceName,
    ];
    final address = parts.join(', ');

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.submitStep1({
        'fullName': _fullNameController.text.trim(),
        'address': address,
        'age': _ageController.text.trim(),
        'gender': _gender!,
        'yearsAtAddress': _yearsAtAddress!,
        'motherName': _motherNameController.text.trim(),
        'fatherName': _fatherNameController.text.trim(),
      });

      if (!mounted) return;

      if (result['statusCode'] == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EducationScreen()),
        );
      } else {
        _showError(result['message'] as String? ?? 'Failed to save');
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
    return Scaffold(
      backgroundColor: _green,
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Step 1: Demographic Profile',
            style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StepProgressBar(currentStep: 1),
                const SizedBox(height: 28),

                _label('Full Legal Name *'),
                _textField(
                  controller: _fullNameController,
                  hint: 'As in documents',
                  maxLength: 100,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!RegExp(r"^[a-zA-Z\s.'-]{2,}$").hasMatch(v.trim()))
                      return 'Letters and spaces only';
                    return null;
                  },
                  formatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s.'-]")),
                    LengthLimitingTextInputFormatter(100),
                  ],
                ),
                const SizedBox(height: 14),

                // Province — fixed as Bukidnon
                _label('Province'),
                _staticField(_provinceName),
                const SizedBox(height: 14),

                // Municipality — API dropdown (Bukidnon), default Maramag
                _label('City / Municipality *'),
                _loadingMunicipalities
                    ? _loadingBox()
                    : _apiDropdown(
                        value: _selectedMunicipalityCode,
                        hint: 'Select municipality',
                        items: _municipalities,
                        validator: (v) => v == null ? 'Required' : null,
                        onChanged: (code) {
                          if (code == null) return;
                          final name = _municipalities.firstWhere(
                              (m) => m['code'] == code,
                              orElse: () => {})['name'];
                          _loadBarangays(code, name ?? '');
                        },
                      ),
                const SizedBox(height: 14),

                // Barangay — API dropdown (cascades from municipality)
                _label('Barangay *'),
                _loadingBarangays
                    ? _loadingBox()
                    : _apiDropdown(
                        value: _selectedBarangay,
                        hint: _selectedMunicipalityCode == null
                            ? 'Select municipality first'
                            : 'Select barangay',
                        items: _barangays
                            .map((b) => {'code': b['name']!, 'name': b['name']!})
                            .toList(),
                        validator: (v) => v == null ? 'Required' : null,
                        onChanged: (v) => setState(() {
                          _selectedBarangay = v;
                          _selectedPurok = null;
                        }),
                      ),
                const SizedBox(height: 14),

                // Purok — shown when Dologon is selected
                if (_isDologon) ...[
                  _label('Purok *'),
                  _simpleDropdown(
                    value: _selectedPurok,
                    hint: 'Select purok',
                    items: _dologonPuroks,
                    validator: (v) => v == null ? 'Required' : null,
                    onChanged: (v) => setState(() => _selectedPurok = v),
                  ),
                  const SizedBox(height: 14),
                ],

                // House / Street / Block (optional detail)
                _label('House No. / Street (optional)'),
                _textField(
                  controller: _houseStreetController,
                  hint: 'e.g. Block 4, Lot 12',
                  maxLength: 100,
                ),
                const SizedBox(height: 14),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Age *'),
                          _textField(
                            controller: _ageController,
                            hint: '18+',
                            keyboardType: TextInputType.number,
                            formatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null) return 'Required';
                              if (n < 18) return 'Must be 18+';
                              if (n > 120) return 'Invalid';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Gender *'),
                          _simpleDropdown(
                            value: _gender,
                            hint: 'Select',
                            items: _genders,
                            onChanged: (v) => setState(() => _gender = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _label('Years at Address *'),
                _simpleDropdown(
                  value: _yearsAtAddress,
                  hint: 'Select',
                  items: _yearsOptions,
                  onChanged: (v) => setState(() => _yearsAtAddress = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                _label("Mother's Full Name *"),
                _textField(
                  controller: _motherNameController,
                  hint: 'Full name',
                  maxLength: 100,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!RegExp(r"^[a-zA-Z\s.'-]{2,}$").hasMatch(v.trim()))
                      return 'Letters and spaces only';
                    return null;
                  },
                  formatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s.'-]")),
                    LengthLimitingTextInputFormatter(100),
                  ],
                ),
                const SizedBox(height: 14),

                _label("Father's Full Name *"),
                _textField(
                  controller: _fatherNameController,
                  hint: 'Full name',
                  maxLength: 100,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!RegExp(r"^[a-zA-Z\s.'-]{2,}$").hasMatch(v.trim()))
                      return 'Letters and spaces only';
                    return null;
                  },
                  formatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s.'-]")),
                    LengthLimitingTextInputFormatter(100),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Terms & Data Privacy ──────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _agreedToTerms
                          ? _limeGreen
                          : Colors.white.withOpacity(0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Privacy & Terms of Use',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'In compliance with Republic Act No. 10173, also known as the '
                        'Data Privacy Act of 2012, Barangay Dologon, Maramag, Bukidnon '
                        'collects and processes your personal information solely for the '
                        'purpose of providing barangay document request services.\n\n'
                        'Your data will be:\n'
                        '  • Kept strictly confidential and stored securely\n'
                        '  • Used only to verify your identity and process your requests\n'
                        '  • Not shared with third parties without your consent, except '
                        'as required by law\n'
                        '  • Retained only as long as necessary for legal and operational purposes\n\n'
                        'You have the right to access, correct, or request deletion of '
                        'your personal data by contacting the Barangay Secretary.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreedToTerms,
                              onChanged: (v) =>
                                  setState(() => _agreedToTerms = v ?? false),
                              activeColor: _limeGreen,
                              checkColor: _green,
                              side: const BorderSide(
                                  color: Colors.white54, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'I have read and I agree to the Terms of Use and Data Privacy '
                              'Policy. I consent to the collection and processing of my '
                              'personal information as stated above.',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_agreedToTerms) ? null : _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _agreedToTerms ? _limeGreen : Colors.white24,
                      foregroundColor:
                          _agreedToTerms ? Colors.black : Colors.white38,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.black54))
                        : const Text('Continue to Step 2',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );

  /// Read-only display for fixed values (e.g. Province = Bukidnon).
  Widget _staticField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(value,
          style: const TextStyle(
              color: _green, fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }

  Widget _loadingBox() => Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF1A6B1A)),
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      style: const TextStyle(
          color: _green, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFF7BAE7B), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none),
        errorStyle:
            const TextStyle(color: Colors.orangeAccent, fontSize: 11),
        counterStyle:
            const TextStyle(color: Colors.white54, fontSize: 10),
      ),
    );
  }

  /// Dropdown backed by PSGC API list (code/name pairs).
  Widget _apiDropdown({
    required String? value,
    required String hint,
    required List<Map<String, String>> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      validator: validator,
      onChanged: items.isEmpty ? null : onChanged,
      dropdownColor: Colors.white,
      isExpanded: true,
      style: const TextStyle(
          color: _green, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFF7BAE7B), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none),
        errorStyle:
            const TextStyle(color: Colors.orangeAccent, fontSize: 11),
      ),
      items: items
          .map((e) => DropdownMenuItem(
                value: e['code'],
                child: Text(e['name']!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _green)),
              ))
          .toList(),
    );
  }

  /// Dropdown for static string lists (gender, years, puroks, etc.).
  Widget _simpleDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      validator: validator,
      onChanged: onChanged,
      dropdownColor: Colors.white,
      isExpanded: true,
      style: const TextStyle(
          color: _green, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFF7BAE7B), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none),
        errorStyle:
            const TextStyle(color: Colors.orangeAccent, fontSize: 11),
      ),
      items: items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(color: _green)),
              ))
          .toList(),
    );
  }
}
