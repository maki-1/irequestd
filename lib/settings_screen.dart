import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'login_screen.dart';
import 'my_requests_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _green = Color(0xFF1A6B1A);

  bool _smsNotif = true;
  bool _emailNotif = true;
  bool _pushNotif = true;

  String _username = '';
  String _email = '';
  String _avatarFilename = '';
  Uint8List? _localAvatar; // preview before upload

  bool _avatarUploading = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getUser();
    if (!mounted) return;
    setState(() {
      _username = user?['username'] as String? ?? '';
      _email = user?['email'] as String? ?? '';
      _avatarFilename = user?['avatar'] as String? ?? '';
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _smsNotif = prefs.getBool('notif_sms') ?? true;
      _emailNotif = prefs.getBool('notif_email') ?? true;
      _pushNotif = prefs.getBool('notif_push') ?? true;
    });
  }

  Future<void> _saveNotif(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final source = await _showPickerSource();
    if (source == null) return;

    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final filename = picked.name.isNotEmpty ? picked.name : 'avatar.jpg';
    setState(() {
      _localAvatar = bytes;
      _avatarUploading = true;
    });

    final res = await ApiService.uploadAvatar(picked.path, bytes, filename);
    if (!mounted) return;

    if (res['statusCode'] == 200) {
      final newFilename = res['avatar'] as String? ?? '';
      setState(() {
        _avatarFilename = newFilename;
        _avatarUploading = false;
      });
      // Refresh cached user
      await ApiService.getMe();
      _showSnack('Profile photo updated!', isError: false);
    } else {
      setState(() {
        _localAvatar = null;
        _avatarUploading = false;
      });
      _showSnack(res['message'] as String? ?? 'Upload failed');
    }
  }

  Future<ImageSource?> _showPickerSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Change Profile Photo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.camera_alt, color: _green),
              ),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.photo_library, color: _green),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure? Your session will end.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
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

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : _green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final avatarUrl = ApiService.avatarUrl(_avatarFilename);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Settings',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          // ── Profile Card ────────────────────────────────────────────
          Container(
            color: _green,
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 28),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.white24,
                        backgroundImage: _localAvatar != null
                            ? MemoryImage(_localAvatar!) as ImageProvider
                            : (avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null),
                        child: (_localAvatar == null && avatarUrl.isEmpty)
                            ? Text(
                                _username.isEmpty
                                    ? '?'
                                    : _username[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    if (_avatarUploading)
                      const Positioned.fill(
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: Colors.black38,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: _green, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 16, color: _green),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _username.isEmpty ? '...' : _username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _email,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // ── ACCOUNT section ─────────────────────────────────────────
          _sectionHeader('ACCOUNT'),
          _menuTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: _showChangePasswordSheet,
          ),

          // ── NOTIFICATIONS section ────────────────────────────────────
          _sectionHeader('NOTIFICATIONS'),
          _toggleTile(
            icon: Icons.sms_outlined,
            title: 'SMS Notifications',
            value: _smsNotif,
            onChanged: (v) {
              setState(() => _smsNotif = v);
              _saveNotif('notif_sms', v);
            },
          ),
          _toggleTile(
            icon: Icons.email_outlined,
            title: 'Email Notifications',
            value: _emailNotif,
            onChanged: (v) {
              setState(() => _emailNotif = v);
              _saveNotif('notif_email', v);
            },
          ),
          _toggleTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            value: _pushNotif,
            onChanged: (v) {
              setState(() => _pushNotif = v);
              _saveNotif('notif_push', v);
            },
          ),

          // ── SUPPORT section ─────────────────────────────────────────
          _sectionHeader('SUPPORT'),
          _menuTile(
            icon: Icons.help_outline,
            title: 'Help & FAQ',
            onTap: () {},
          ),
          _menuTile(
            icon: Icons.support_agent_outlined,
            title: 'Contact Support',
            onTap: () {},
          ),
          _menuTile(
            icon: Icons.info_outline,
            title: 'About App',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'iRequestD',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 Dologon Barangay',
            ),
          ),

          // ── PRIVACY section ─────────────────────────────────────────
          _sectionHeader('PRIVACY'),
          _menuTile(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            onTap: () {},
          ),
          _menuTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {},
          ),

          // ── Logout button ────────────────────────────────────────────
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Reusable widgets ─────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
        child: Text(title,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black45,
                letterSpacing: 1.2)),
      );

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(icon, color: _green, size: 22),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
          trailing:
              const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
          onTap: onTap,
        ),
      );

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required bool value,
    required void Function(bool) onChanged,
  }) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(icon, color: _green, size: 22),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
          trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _green,
          ),
        ),
      );

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 2,
      selectedItemColor: _green,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      onTap: (i) {
        if (i == 0) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/dashboard', (_) => false);
        } else if (i == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Requests'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            activeIcon: Icon(Icons.settings),
            label: 'Settings'),
      ],
    );
  }
}

// ── Change Password Bottom Sheet ─────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  static const Color _green = Color(0xFF1A6B1A);

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text.trim();
    final newPw = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    if (newPw != confirm) {
      _showSnack('New passwords do not match');
      return;
    }
    if (newPw.length < 8) {
      _showSnack('Password must be at least 8 characters');
      return;
    }

    setState(() => _loading = true);
    final res = await ApiService.changePassword(
      currentPassword: current,
      newPassword: newPw,
      confirmPassword: confirm,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (res['statusCode'] == 200) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password changed successfully!'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      _showSnack(res['message'] as String? ?? 'Failed to change password');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Change Password',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            const SizedBox(height: 4),
            const Text('Keep your account secure',
                style: TextStyle(fontSize: 13, color: Colors.black45)),
            const SizedBox(height: 24),
            _pwField(
              controller: _currentCtrl,
              label: 'Current Password',
              obscure: !_showCurrent,
              toggle: () => setState(() => _showCurrent = !_showCurrent),
            ),
            const SizedBox(height: 14),
            _pwField(
              controller: _newCtrl,
              label: 'New Password',
              obscure: !_showNew,
              toggle: () => setState(() => _showNew = !_showNew),
            ),
            const SizedBox(height: 14),
            _pwField(
              controller: _confirmCtrl,
              label: 'Confirm New Password',
              obscure: !_showConfirm,
              toggle: () => setState(() => _showConfirm = !_showConfirm),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Update Password',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _pwField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black45),
        filled: true,
        fillColor: const Color(0xFFF4F6F4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.black38,
            size: 20,
          ),
          onPressed: toggle,
        ),
      ),
    );
  }
}
