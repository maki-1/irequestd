import 'package:flutter/material.dart';
import 'services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _green = Color(0xFF1A6B1A);

  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.fetchDemographicProfile();
      if (mounted) setState(() { _profile = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load profile.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('My Profile',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final p = _profile!;
    final isPwd = p['isPwd'] == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar + name header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white24,
                child: Text(
                  _initials(p['fullName'] as String? ?? p['username'] as String? ?? '?'),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                (p['fullName'] as String?)?.isNotEmpty == true
                    ? p['fullName'] as String
                    : p['username'] as String? ?? '',
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '@${p['username'] ?? ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (isPwd) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.accessibility_new_rounded, size: 14, color: _green),
                      SizedBox(width: 4),
                      Text('PWD',
                          style: TextStyle(
                              color: _green, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        _section('Personal Information', [
          _row(Icons.person_outline, 'Full Name', p['fullName']),
          _row(Icons.cake_outlined, 'Age', p['age']?.toString()),
          _row(Icons.wc_outlined, 'Gender', p['gender']),
          _row(Icons.phone_outlined, 'Contact Number', p['contactNumber']),
          _row(Icons.email_outlined, 'Email', p['email']),
        ]),

        const SizedBox(height: 16),

        _section('Address', [
          _row(Icons.home_outlined, 'Address', p['address']),
          _row(Icons.calendar_today_outlined, 'Years at Address', p['yearsAtAddress']),
        ]),

        const SizedBox(height: 16),

        _section('Family', [
          _row(Icons.man_outlined, 'Father\'s Name', p['fatherName']),
          _row(Icons.woman_outlined, 'Mother\'s Maiden Name', p['motherName']),
        ]),

        const SizedBox(height: 16),

        _section('Education', [
          _row(Icons.school_outlined, 'Education Level', p['educationLevel']),
          _row(Icons.account_balance_outlined, 'School / University', p['school']),
          _row(Icons.menu_book_outlined, 'Course / Strand', p['course']),
          _row(Icons.event_outlined, 'Year Graduated', p['yearGraduated']),
        ]),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _section(String title, List<Widget> rows) {
    final visible = rows.whereType<_InfoRow>().where((r) => r.value.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black45,
                letterSpacing: 1.2),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i < rows.length - 1)
                  const Divider(height: 1, indent: 52, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, dynamic rawValue) {
    final value = rawValue?.toString().trim() ?? '';
    return _InfoRow(icon: icon, label: label, value: value);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1A6B1A)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.black45)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
