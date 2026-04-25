import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'request_document_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFF1A6B1A);

  late final TabController _tabController;
  List<dynamic> _requests = [];
  List<dynamic> _readyForPickup = [];
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _cachedUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getUser();
    if (mounted) setState(() => _cachedUser = user);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.fetchRequests(),
        ApiService.fetchCompletedDocuments(),
      ]);
      if (mounted) setState(() {
        _requests = results[0];
        _readyForPickup = results[1];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Failed to load requests.';
        _loading = false;
      });
    }
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  IconData _docIcon(String type) {
    switch (type) {
      case 'Certificate of Residency': return Icons.home_outlined;
      case 'Certificate of Indigency': return Icons.badge_outlined;
      default: return Icons.assignment_outlined;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Ready': return Colors.green;
      case 'Processing': return Colors.orange;
      case 'Rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Ready': return Icons.check_circle_outline;
      case 'Processing': return Icons.hourglass_empty_rounded;
      case 'Rejected': return Icons.cancel_outlined;
      default: return Icons.schedule_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickupCount = _readyForPickup.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('My Requests',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4CFF4C),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            const Tab(text: 'Requests'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ready for Pickup'),
                  if (pickupCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pickupCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 1: Requests ───────────────────────────────────
                RefreshIndicator(
                  color: _green,
                  onRefresh: _loadRequests,
                  child: _requests.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _requests.length,
                          itemBuilder: (_, i) =>
                              _buildCard(_requests[i] as Map<String, dynamic>),
                        ),
                ),

                // ── Tab 2: Ready for Pickup ───────────────────────────
                RefreshIndicator(
                  color: _green,
                  onRefresh: _loadRequests,
                  child: _readyForPickup.isEmpty
                      ? _emptyPickup()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _readyForPickup.length,
                          itemBuilder: (_, i) => _buildPickupCard(
                              _readyForPickup[i] as Map<String, dynamic>),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _bottomNav(context, 1),
    );
  }

  Widget _emptyPickup() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.storefront_outlined, size: 56, color: Colors.black26),
            SizedBox(height: 16),
            Text('No documents ready for pickup',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black45)),
            SizedBox(height: 8),
            Text('You\'ll see your claim code here once\nyour document is ready.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black38, fontSize: 13)),
          ],
        ),
      );

  Widget _sectionHeader(String text, {Color color = Colors.black45}) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 2),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1.2)),
      );

  void _showPickupDetail(Map<String, dynamic> d) {
    final docType    = d['documentType'] as String? ?? '—';
    final claimCode  = d['claimCode']    as String? ?? '—';
    final fullName   = d['fullName']     as String? ?? '—';
    final avatarFile = _cachedUser?['avatar'] as String? ?? '';
    final avatarUrl  = ApiService.avatarUrl(avatarFile);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFFE8F5E9),
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A6B1A)),
                      )
                    : null,
              ),
              const SizedBox(height: 12),

              // Full name
              Text(fullName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87)),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Document requested
              _detailRow(Icons.description_outlined, 'Document', docType),
              const SizedBox(height: 12),

              // Claim code box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF1A6B1A), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CLAIM CODE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A6B1A),
                            letterSpacing: 1.5)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(claimCode,
                              style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1A6B1A),
                                  letterSpacing: 4)),
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: claimCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Claim code copied!'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A6B1A)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.copy_outlined,
                                size: 18, color: Color(0xFF1A6B1A)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A6B1A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text('Close',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.black45),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black38,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ],
          ),
        ],
      );

  Widget _buildPickupCard(Map<String, dynamic> d) {
    final docType = d['documentType'] as String? ?? '—';
    final claimCode = d['claimCode'] as String? ?? '';
    final completedAt = d['completedAt'] != null
        ? _formatDate(d['completedAt'] as String)
        : (d['createdAt'] != null ? _formatDate(d['createdAt'] as String) : '');

    return GestureDetector(
      onTap: () => _showPickupDetail(d),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_docIcon(docType),
                      color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(docType,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                      if (completedAt.isNotEmpty)
                        Text('Completed: $completedAt',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black45)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Ready',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFC8E6C9)),
            const SizedBox(height: 14),

            // Claim code
            const Text('CLAIM CODE',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.green,
                    letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    claimCode.isNotEmpty ? claimCode : '—',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A6B1A),
                        letterSpacing: 5),
                  ),
                ),
                if (claimCode.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: claimCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Claim code copied!'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.copy_outlined,
                          size: 18, color: Colors.green),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Show this code to the barangay secretary to claim your document.',
              style: TextStyle(
                  fontSize: 11, color: Color(0xFF2E7D32), height: 1.4),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📂', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('No requests yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          const Text('Tap below to create your first request',
              style: TextStyle(color: Colors.black38, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RequestDocumentScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            child: const Text('Create Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> r) {
    final status = r['status'] as String? ?? 'Pending';
    final docType = r['documentType'] as String? ?? r['title'] as String? ?? '—';
    final reqId = (r['_id'] as String).substring(0, 8).toUpperCase();
    final submitted = _formatDate(r['createdAt'] as String);
    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_docIcon(docType), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(docType,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 13, color: color),
                      const SizedBox(width: 4),
                      Text(status,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Request ID + Date
            Text('REQ-$reqId',
                style: const TextStyle(
                    fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text('Submitted: $submitted',
                style: const TextStyle(fontSize: 12, color: Colors.black45)),

            // Purpose
            if (r['purpose'] != null) ...[
              const SizedBox(height: 4),
              Text('Purpose: ${r['purpose']}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],

            // Action row
            if (status == 'Processing') ...[
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.info_outline, size: 13, color: Colors.orange),
                  SizedBox(width: 4),
                  Text('Being processed by the barangay office',
                      style: TextStyle(fontSize: 11, color: Colors.orange)),
                ],
              ),
            ] else if (status == 'Pending') ...[
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.schedule_outlined, size: 13, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('Queued — awaiting processing',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ],
        ),
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
    Navigator.pushNamed(context, '/settings');
  }
}
