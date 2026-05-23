import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../login_screen.dart';
import '../services/api_service.dart';
import '../services/llama_service.dart';
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

  static const _fixedMunicipality = 'Maramag';
  static const _fixedBarangay = 'Dologon';

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
    'Purok 11',
    'Purok 12',
    'Purok 13',
    'Purok 14',
    'Purok 15',
    'Purok 16',
    'Purok 17',
    'Purok 18',
    'Purok 19',
    'Purok 20',
    'Purok 21',
  ];

  static const _indigentOptions = ['Yes', 'No', 'Others'];

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _houseStreetController = TextEditingController();
  final _yearsAtAddressController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _indigentOtherController = TextEditingController();

  String? _sex;
  String? _pwdStatus;
  String? _indigentStatus;
  DateTime? _selectedBirthday;

  // Unified proof document — PWD ID, PSA Birth Cert, or Senior Citizen Card
  XFile? _proofFile;
  Uint8List? _proofBytes;

  // Proof document validation state
  bool _proofValidating = false;
  bool? _proofValid;
  String _proofInvalidReason = '';

  bool _isLoading = false;
  bool _agreedToTerms = false;
  bool _agreedToCredentials = false;

  static const _provinceName = 'Bukidnon';

  String? _selectedPurok;

  static const _sexOptions = ['Male', 'Female'];

  int? get _ageInt {
    if (_selectedBirthday == null) return null;
    final today = DateTime.now();
    int age = today.year - _selectedBirthday!.year;
    if (today.month < _selectedBirthday!.month ||
        (today.month == _selectedBirthday!.month &&
            today.day < _selectedBirthday!.day)) {
      age--;
    }
    return age;
  }

  bool get _proofRequired =>
      _pwdStatus == 'Yes' ||
      (_ageInt != null && _ageInt! < 18) ||
      (_ageInt != null && _ageInt! >= 60);

  String get _proofLabel {
    if (_pwdStatus == 'Yes') return 'PWD ID';
    if (_ageInt != null && _ageInt! < 18) return 'PSA Birth Certificate';
    if (_ageInt != null && _ageInt! >= 60) return 'Senior Citizen ID';
    return '';
  }

  String _formatBirthday(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _houseStreetController.dispose();
    _yearsAtAddressController.dispose();
    _motherNameController.dispose();
    _fatherNameController.dispose();
    _indigentOtherController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A6B1A),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedBirthday = picked);
    }
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBirthday == null) {
      _showError('Please select your birthday.');
      return;
    }

    if (_indigentStatus == null) {
      _showError('Please select your indigent status.');
      return;
    }

    if (_indigentStatus == 'Others' &&
        _indigentOtherController.text.trim().isEmpty) {
      _showError('Please specify your indigent status.');
      return;
    }

    final parts = <String>[
      if (_selectedPurok != null) _selectedPurok!,
      if (_houseStreetController.text.trim().isNotEmpty)
        _houseStreetController.text.trim(),
      'Brgy. $_fixedBarangay',
      _fixedMunicipality,
      _provinceName,
    ];
    final address = parts.join(', ');

    if (_proofRequired && _proofFile == null) {
      _showError('Please attach your $_proofLabel.');
      return;
    }
    if (_proofRequired && _proofValid == false) {
      _showError(
          'The uploaded document does not appear to be a valid $_proofLabel. Please upload the correct document.');
      return;
    }
    if (_proofRequired && _proofValidating) {
      _showError('Please wait — verifying your document.');
      return;
    }

    final birthday =
        '${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}';

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.submitStep1(
        {
          'fullName': _fullNameController.text.trim(),
          'address': address,
          'birthday': birthday,
          'sex': _sex!,
          'yearsOfResidency': _yearsAtAddressController.text.trim(),
          'motherName': _motherNameController.text.trim(),
          'fatherName': _fatherNameController.text.trim(),
          'isPwd': _pwdStatus == 'Yes',
          'indigent': _indigentStatus == 'Others'
              ? _indigentOtherController.text.trim()
              : _indigentStatus!,
        },
        proofBytes: _proofBytes,
        proofFileName: _proofFile?.name,
      );

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

  Future<void> _pickProofDocument() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Upload $_proofLabel',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: Color(0xFF1A6B1A)),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final file = await ImagePicker()
                    .pickImage(source: ImageSource.camera, imageQuality: 85);
                if (file != null) _setProofFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Color(0xFF1A6B1A)),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final file = await ImagePicker()
                    .pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (file != null) _setProofFile(file);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _setProofFile(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('File too large (max 5MB)'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    setState(() {
      _proofFile = file;
      _proofBytes = bytes;
      _proofValid = null;
      _proofInvalidReason = '';
    });
    await _validateProof(bytes);
  }

  Future<void> _validateProof(Uint8List bytes) async {
    final docType = _proofLabel;
    if (docType.isEmpty) return;

    setState(() => _proofValidating = true);
    final result = await LlamaService.validateProofDocument(
      imageBytes: bytes,
      expectedDocType: docType,
    );
    if (!mounted) return;
    setState(() {
      _proofValidating = false;
      _proofValid = result.valid;
      _proofInvalidReason = result.reason;
    });
  }

  void _clearProof() {
    setState(() {
      _proofFile = null;
      _proofBytes = null;
      _proofValid = null;
      _proofValidating = false;
      _proofInvalidReason = '';
    });
  }

  Widget _buildProofUpload() {
    final borderColor = _proofFile == null
        ? Colors.white30
        : _proofValid == false
            ? Colors.redAccent
            : Colors.white54;

    return GestureDetector(
      onTap: _proofValidating ? null : _pickProofDocument,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: _proofFile == null
            ? Column(
                children: [
                  const Icon(Icons.upload_file_rounded,
                      color: Colors.white54, size: 36),
                  const SizedBox(height: 8),
                  Text('Tap to upload $_proofLabel',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('JPG, PNG  •  Max 5MB',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              )
            : Column(
                children: [
                  if (_proofBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_proofBytes!,
                          height: 100, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 10),

                  if (_proofValidating)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white54),
                        ),
                        SizedBox(width: 8),
                        Text('Verifying document…',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    )
                  else if (_proofValid == false)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_rounded,
                            size: 16, color: Colors.redAccent),
                        SizedBox(width: 6),
                        Text('Invalid document',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.insert_drive_file_outlined,
                            size: 14, color: Colors.white54),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(_proofFile!.name,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),

                  TextButton.icon(
                    onPressed: _proofValidating ? null : _clearProof,
                    icon: const Icon(Icons.close,
                        size: 14, color: Colors.redAccent),
                    label: const Text('Remove',
                        style:
                            TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProofHint() {
    String hint;
    if (_pwdStatus == 'Yes') {
      hint =
          'Upload a clear photo of your PWD ID. This will be used when requesting free documents.';
    } else if (_ageInt != null && _ageInt! < 18) {
      hint =
          'As a minor, upload your PSA Birth Certificate. You only need to do this once.';
    } else {
      hint =
          'As a Senior Citizen (60+), upload your Senior Citizen ID. You only need to do this once.';
    }
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(hint,
          style: const TextStyle(
              color: Colors.white54, fontSize: 11.5, height: 1.4)),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Your progress is saved. You can continue from this step when you log back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ApiService.clearSession();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _confirmLogout,
          ),
        ],
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

                // ── Full Name ─────────────────────────────────────────
                _label('Full Legal Name', isRequired: true),
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
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _agreedToCredentials,
                        onChanged: (v) =>
                            setState(() => _agreedToCredentials = v ?? false),
                        activeColor: _limeGreen,
                        checkColor: _green,
                        side: const BorderSide(color: Colors.white54, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'I agree that all my credentials are correct.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Birthday ──────────────────────────────────────────
                _label('Birthday', isRequired: true),
                _buildBirthdayField(),
                const SizedBox(height: 14),

                // ── Barangay (fixed) ──────────────────────────────────
                _label('Barangay'),
                _staticField(_fixedBarangay),
                const SizedBox(height: 14),

                // ── Purok ─────────────────────────────────────────────
                _label('Purok', isRequired: true),
                _simpleDropdown(
                  value: _selectedPurok,
                  hint: 'Select purok',
                  items: _dologonPuroks,
                  validator: (v) => v == null ? 'Required' : null,
                  onChanged: (v) => setState(() => _selectedPurok = v),
                ),
                const SizedBox(height: 14),

                // ── House / Street (optional) ─────────────────────────
                _label('House No. / Street (optional)'),
                _textField(
                  controller: _houseStreetController,
                  hint: 'e.g. Block 4, Lot 12',
                  maxLength: 100,
                ),
                const SizedBox(height: 14),

                // ── Sex ───────────────────────────────────────────────
                _label('Sex', isRequired: true),
                _simpleDropdown(
                  value: _sex,
                  hint: 'Select',
                  items: _sexOptions,
                  onChanged: (v) => setState(() => _sex = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // ── Years at Address ──────────────────────────────────
                _label('Year/s of Residency', isRequired: true),
                _textField(
                  controller: _yearsAtAddressController,
                  hint: 'e.g. 5 years',
                  keyboardType: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── PWD ───────────────────────────────────────────────
                _label('PWD?', isRequired: true),
                _simpleDropdown(
                  value: _pwdStatus,
                  hint: 'Yes or No',
                  items: const ['Yes', 'No'],
                  onChanged: (v) => setState(() {
                    _pwdStatus = v;
                    if (!_proofRequired) {
                      _proofFile = null;
                      _proofBytes = null;
                    }
                  }),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // ── Indigent ──────────────────────────────────────────
                _label('Indigent', isRequired: true),
                _simpleDropdown(
                  value: _indigentStatus,
                  hint: 'Select',
                  items: _indigentOptions,
                  onChanged: (v) => setState(() {
                    _indigentStatus = v;
                    if (v != 'Others') _indigentOtherController.clear();
                  }),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                if (_indigentStatus == 'Others') ...[
                  const SizedBox(height: 10),
                  _label('Please specify', isRequired: true),
                  _textField(
                    controller: _indigentOtherController,
                    hint: 'e.g. Solo parent, displaced farmer…',
                    maxLength: 100,
                    validator: (v) {
                      if (_indigentStatus == 'Others' &&
                          (v == null || v.trim().isEmpty)) return 'Required';
                      return null;
                    },
                    formatters: [LengthLimitingTextInputFormatter(100)],
                  ),
                ],
                const SizedBox(height: 14),

                // ── Proof document ────────────────────────────────────
                if (_proofRequired) ...[
                  _label('$_proofLabel (required)', isRequired: true),
                  const SizedBox(height: 2),
                  _buildProofHint(),
                  const SizedBox(height: 8),
                  _buildProofUpload(),
                  const SizedBox(height: 14),
                ],

                // ── Mother's Name ─────────────────────────────────────
                _label("Full Mother's Maiden Name", isRequired: true),
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

                // ── Father's Name ─────────────────────────────────────
                _label("Father's Full Name", isRequired: true),
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
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.5),
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
                    onPressed:
                        (_isLoading || !_agreedToTerms || !_agreedToCredentials)
                            ? null
                            : _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (_agreedToTerms && _agreedToCredentials) ? _limeGreen : Colors.white24,
                      foregroundColor:
                          (_agreedToTerms && _agreedToCredentials) ? Colors.black : Colors.white38,
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

  Widget _label(String text, {bool isRequired = false}) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: RichText(
          text: TextSpan(
            text: text,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600),
            children: isRequired
                ? const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w700),
                    )
                  ]
                : [],
          ),
        ),
      );

  Widget _buildBirthdayField() {
    return GestureDetector(
      onTap: _pickBirthday,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedBirthday != null
                    ? _formatBirthday(_selectedBirthday!)
                    : 'Select birthday',
                style: TextStyle(
                  color: _selectedBirthday != null
                      ? _green
                      : const Color(0xFF7BAE7B),
                  fontSize: 15,
                  fontWeight: _selectedBirthday != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                color: Color(0xFF7BAE7B), size: 18),
          ],
        ),
      ),
    );
  }

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
