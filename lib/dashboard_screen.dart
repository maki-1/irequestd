import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'request_document_screen.dart';
import 'my_requests_screen.dart';
import 'settings_screen.dart';

class _StatusConfig {
  final Color color;
  final IconData icon;
  final String label;
  final String? subtitle;
  const _StatusConfig({
    required this.color,
    required this.icon,
    required this.label,
    this.subtitle,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _limeGreen = Color(0xFF4CFF4C);

  String _username = '';
  String _firstName = '';
  String _avatarFilename = '';
  String _accountStatus = 'draft';   // draft | pending | approved | rejected
  bool _isVerified = false;
  Map<String, dynamic> _summary = {
    'total': 0, 'pending': 0, 'processing': 0, 'ready': 0, 'rejected': 0
  };
  List<dynamic> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Fetch fresh status from server, fall back to cached
      final user = await ApiService.getMe() ?? await ApiService.getUser();
      final summary = await ApiService.fetchSummary();
      final requests = await ApiService.fetchRequests();
      if (!mounted) return;
      setState(() {
        final full = user?['username'] as String? ?? '';
        _username = full.split(' ').first;
        final fullName = user?['fullName'] as String? ?? '';
        _firstName = fullName.isNotEmpty
            ? fullName.trim().split(' ').first
            : _username;
        _avatarFilename = user?['avatar'] as String? ?? '';
        _accountStatus = user?['accountStatus'] as String? ?? 'draft';
        _isVerified = user?['isVerified'] as bool? ?? false;
        _summary = summary;
        _requests = requests;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _timeAgo(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return '${diff.inDays ~/ 7} week${diff.inDays ~/ 7 == 1 ? '' : 's'} ago';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Ready': return Colors.green;
      case 'Processing': return Colors.orange;
      case 'Rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : RefreshIndicator(
              color: _green,
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // ── Header ─────────────────────────────────────────
                  SliverAppBar(
                    backgroundColor: _green,
                    expandedHeight: 110,
                    floating: false,
                    pinned: true,
                    automaticallyImplyLeading: false,
                    flexibleSpace: FlexibleSpaceBar(
                      background: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Welcome back,',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13)),
                                    Text(
                                      _firstName.isEmpty ? '...' : _firstName,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SettingsScreen()),
                                ),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: _limeGreen.withValues(alpha: 0.3),
                                  backgroundImage: _avatarFilename.isNotEmpty
                                      ? NetworkImage(ApiService.avatarUrl(_avatarFilename))
                                      : null,
                                  child: _avatarFilename.isEmpty
                                      ? Text(
                                          _username.isEmpty
                                              ? '?'
                                              : _username[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([

                        // ── Services Grid ──────────────────────────
                        _sectionTitle('SERVICES'),
                        const SizedBox(height: 10),
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 80,
                                    child: _serviceCard(
                                      icon: Icons.assignment_outlined,
                                      label: 'Barangay\nClearance',
                                      subtitle: 'For general purposes',
                                      color: const Color(0xFFFFAB76),
                                      onTap: () => _openRequest('Barangay Clearance'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 80,
                                    child: _serviceCard(
                                      icon: Icons.home_outlined,
                                      label: 'Certificate of\nResidency',
                                      subtitle: 'Proof of address',
                                      color: const Color(0xFF80D98A),
                                      onTap: () => _openRequest('Certificate of Residency'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 80,
                                    child: _serviceCard(
                                      icon: Icons.badge_outlined,
                                      label: 'Certificate of\nIndigency',
                                      subtitle: 'For financial aid',
                                      color: const Color(0xFFBEA9F0),
                                      onTap: () => _openRequest('Certificate of Indigency'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 80,
                                    child: _serviceCard(
                                      icon: Icons.inbox_outlined,
                                      label: 'My\nRequests',
                                      subtitle: 'Track your documents',
                                      color: const Color(0xFF7ECEF4),
                                      badge: (_summary['pending'] ?? 0) > 0
                                          ? '${_summary['pending']}'
                                          : null,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const MyRequestsScreen()),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Account Status ─────────────────────────
                        _sectionTitle('ACCOUNT STATUS'),
                        const SizedBox(height: 10),
                        _accountStatusCard(),
                        const SizedBox(height: 24),

                        // ── Recent Activity ────────────────────────
                        _sectionTitle('RECENT ACTIVITY'),
                        const SizedBox(height: 10),
                        if (_requests.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text('No activity yet',
                                  style: TextStyle(
                                      color: Colors.black38, fontSize: 13)),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: _requests
                                  .take(5)
                                  .map((r) {
                                    final map = r as Map<String, dynamic>;
                                    final status = map['status'] as String? ?? 'Pending';
                                    final docType = map['documentType'] as String?
                                        ?? map['title'] as String? ?? '—';
                                    final time = _timeAgo(map['createdAt'] as String);
                                    final color = _statusColor(status);
                                    return _activityTile(
                                      docType: docType,
                                      status: status,
                                      time: time,
                                      color: color,
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _bottomNav(context, 0),
    );
  }

  void _openRequest(String docType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestDocumentScreen(preselectedType: docType),
      ),
    );
  }

  Widget _accountStatusCard() {
    final cfg = _statusConfig(_accountStatus, _isVerified);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: cfg.color, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cfg.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(cfg.icon, color: cfg.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cfg.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cfg.color)),
                if (cfg.subtitle != null)
                  Text(cfg.subtitle!,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _statusConfig(String accountStatus, bool isVerified) {
    if (!isVerified) {
      return _StatusConfig(
        color: Colors.orange,
        icon: Icons.warning_amber_outlined,
        label: 'Phone Not Verified',
        subtitle: 'Please verify your phone number',
      );
    }
    switch (accountStatus) {
      case 'approved':
        return _StatusConfig(
          color: Colors.green,
          icon: Icons.verified_outlined,
          label: 'Account Verified',
          subtitle: 'You have full access',
        );
      case 'pending':
        return _StatusConfig(
          color: Colors.orange,
          icon: Icons.hourglass_empty_outlined,
          label: 'Under Review',
          subtitle: 'Your documents are being reviewed',
        );
      case 'rejected':
        return _StatusConfig(
          color: Colors.red,
          icon: Icons.cancel_outlined,
          label: 'Verification Rejected',
          subtitle: 'Please re-submit your documents',
        );
      default: // draft
        return _StatusConfig(
          color: Colors.blueGrey,
          icon: Icons.edit_outlined,
          label: 'Verification Incomplete',
          subtitle: 'Complete your profile to get verified',
        );
    }
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.black45,
            letterSpacing: 1.2),
      );

  Widget _serviceCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: label + action button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label.replaceAll('\n', ' '),
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.65),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_outward,
                          size: 11,
                          color: Colors.black.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                const Spacer(),
                // Icon
                Icon(icon,
                    size: 18,
                    color: Colors.black.withValues(alpha: 0.72)),
                const Spacer(),
                // Subtitle
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.5),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(badge,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _activityTile({
    required String docType,
    required String status,
    required String time,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 3),
          bottom: const BorderSide(color: Color(0xFFF0F0F0), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(docType,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 2),
                Text(time,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black38)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        ],
      ),
    );
  }
}

Widget _bottomNav(BuildContext context, int currentIndex) {
  return BottomNavigationBar(
    currentIndex: currentIndex,
    selectedItemColor: const Color(0xFF1A6B1A),
    unselectedItemColor: Colors.grey,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
    onTap: (i) => _onNavTap(context, i, currentIndex),
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
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Settings'),
    ],
  );
}

void _onNavTap(BuildContext context, int index, int current) {
  if (index == current) return;
  if (index == 0) {
    Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
  } else if (index == 1) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const MyRequestsScreen()));
  } else if (index == 2) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }
}
