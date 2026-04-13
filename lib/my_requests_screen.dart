import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'request_document_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  static const Color _green = Color(0xFF1A6B1A);

  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchRequests();
      if (mounted) setState(() {
        _requests = data;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('My Requests',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : RefreshIndicator(
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
      bottomNavigationBar: _bottomNav(context, 1),
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
            if (status == 'Ready') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Download Document',
                      style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: Color(0xFF1A6B1A)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ] else if (status == 'Processing') ...[
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
