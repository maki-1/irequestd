import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
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
  List<dynamic> _readyForPickup = [];
  List<dynamic> _claimedDocuments = [];
  bool _loading = true;
  final Set<String> _readNotifIds = {};
  // IDs for which an OS notification has already been fired (persisted)
  final Set<String> _seenNotifIds = {};
  bool _seenInitialized = false;

  int get _notifCount =>
      _readyForPickup.where((d) {
        final id = (d as Map<String, dynamic>)['_id']?.toString() ?? '';
        return !_readNotifIds.contains(id);
      }).length +
      _claimedDocuments.where((d) {
        final id = (d as Map<String, dynamic>)['_id']?.toString() ?? '';
        return !_readNotifIds.contains(id);
      }).length +
      _requests.where((r) {
        final map = r as Map<String, dynamic>;
        final id = map['_id']?.toString() ?? '';
        return map['status'] == 'Rejected' && !_readNotifIds.contains(id);
      }).length;

  @override
  void initState() {
    super.initState();
    _loadReadNotifs();
    _loadData();
  }

  Future<void> _loadReadNotifs() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('read_notif_ids') ?? [];
    final seenIds = prefs.getStringList('seen_notif_ids') ?? [];
    _seenInitialized = prefs.getBool('notif_ever_loaded') ?? false;
    if (mounted) {
      setState(() {
        _readNotifIds.addAll(ids);
        _seenNotifIds.addAll(seenIds);
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    if (_readNotifIds.contains(id)) return;
    setState(() => _readNotifIds.add(id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('read_notif_ids', _readNotifIds.toList());
  }

  Future<void> _fireOsNotifications({
    required List<dynamic> pickup,
    required List<dynamic> claimed,
    required List<dynamic> requests,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!_seenInitialized) {
      // First ever load — silently mark everything as seen so we don't
      // flood the user with old notifications on first install.
      for (final d in pickup) { _seenNotifIds.add((d as Map)['_id']?.toString() ?? ''); }
      for (final d in claimed) { _seenNotifIds.add((d as Map)['_id']?.toString() ?? ''); }
      for (final r in requests) { _seenNotifIds.add((r as Map)['_id']?.toString() ?? ''); }
      await prefs.setBool('notif_ever_loaded', true);
      await prefs.setStringList('seen_notif_ids', _seenNotifIds.toList());
      _seenInitialized = true;
      return;
    }

    bool changed = false;
    int notifId = DateTime.now().millisecondsSinceEpoch % 90000 + 1000;

    for (final d in pickup) {
      final doc = d as Map<String, dynamic>;
      final id = doc['_id']?.toString() ?? '';
      if (id.isEmpty || _seenNotifIds.contains(id)) continue;
      final docType = doc['documentType'] as String? ?? 'Document';
      final code = doc['claimCode'] as String? ?? '';
      await NotificationService.show(
        id: notifId++,
        title: 'Ready for Pickup!',
        body: 'Your $docType is ready.${code.isNotEmpty ? ' Claim code: $code' : ''}',
      );
      _seenNotifIds.add(id);
      changed = true;
    }

    for (final d in claimed) {
      final doc = d as Map<String, dynamic>;
      final id = doc['_id']?.toString() ?? '';
      if (id.isEmpty || _seenNotifIds.contains(id)) continue;
      final docType = doc['documentType'] as String? ?? 'Document';
      await NotificationService.show(
        id: notifId++,
        title: 'Document Picked Up',
        body: 'Your $docType has been successfully picked up.',
      );
      _seenNotifIds.add(id);
      changed = true;
    }

    for (final r in requests) {
      final req = r as Map<String, dynamic>;
      final id = req['_id']?.toString() ?? '';
      final status = req['status'] as String? ?? '';
      if (id.isEmpty || status != 'Rejected' || _seenNotifIds.contains(id)) continue;
      final docType = req['documentType'] as String? ?? 'Document';
      await NotificationService.show(
        id: notifId++,
        title: 'Request Rejected',
        body: 'Your $docType request has been rejected.',
      );
      _seenNotifIds.add(id);
      changed = true;
    }

    if (changed) {
      await prefs.setStringList('seen_notif_ids', _seenNotifIds.toList());
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Fetch fresh status from server, fall back to cached on network error
      Map<String, dynamic>? user;
      try { user = await ApiService.getMe(); } catch (_) {}
      user ??= await ApiService.getUser();
      final results = await Future.wait([
        ApiService.fetchSummary(),
        ApiService.fetchRequests(),
        ApiService.fetchCompletedDocuments(),
        ApiService.fetchClaimedDocuments(),
      ]);
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
        _summary = results[0] as Map<String, dynamic>;
        _requests = results[1] as List<dynamic>;
        _readyForPickup = results[2] as List<dynamic>;
        _claimedDocuments = results[3] as List<dynamic>;
        _loading = false;
      });
      await _fireOsNotifications(
        pickup: results[2] as List<dynamic>,
        claimed: results[3] as List<dynamic>,
        requests: results[1] as List<dynamic>,
      );
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
                              // Notification bell
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    onPressed: _showNotifications,
                                    icon: const Icon(
                                        Icons.notifications_outlined,
                                        color: Colors.white,
                                        size: 26),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  if (_notifCount > 0)
                                    Positioned(
                                      top: -2,
                                      right: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: _green, width: 1.5),
                                        ),
                                        child: Text(
                                          _notifCount > 99
                                              ? '99+'
                                              : '$_notifCount',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              height: 1),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Avatar
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

                        // ── My Requests shortcut ───────────────────
                        _sectionTitle('QUICK ACCESS'),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 80,
                          child: _serviceCard(
                            icon: Icons.inbox_outlined,
                            label: 'My Requests',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDocumentPicker,
        backgroundColor: _green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Request',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ),
      bottomNavigationBar: _bottomNav(context, 0),
    );
  }

  void _showDocumentPicker() {
    final docs = [
      {
        'label': 'Barangay Clearance',
        'subtitle': 'For general purposes',
        'icon': Icons.assignment_outlined,
        'color': const Color(0xFFFFAB76),
        'type': 'Barangay Clearance',
      },
      {
        'label': 'Certificate of Residency',
        'subtitle': 'Proof of address',
        'icon': Icons.home_outlined,
        'color': const Color(0xFF80D98A),
        'type': 'Certificate of Residency',
      },
      {
        'label': 'Certificate of Indigency',
        'subtitle': 'For financial aid',
        'icon': Icons.badge_outlined,
        'color': const Color(0xFFBEA9F0),
        'type': 'Certificate of Indigency',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Choose Document',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Select the document you want to request',
                  style: TextStyle(fontSize: 13, color: Colors.black45)),
            ),
            const SizedBox(height: 20),
            ...docs.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _openRequest(d['type'] as String);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: (d['color'] as Color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                (d['color'] as Color).withValues(alpha: 0.4),
                            width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: d['color'] as Color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(d['icon'] as IconData,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d['label'] as String,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87)),
                                Text(d['subtitle'] as String,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black45)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: Colors.black26),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showPickupDetail(Map<String, dynamic> d) {
    final docType   = d['documentType'] as String? ?? '—';
    final claimCode = d['claimCode']    as String? ?? '—';
    final fullName  = d['fullName']     as String? ?? '—';
    final avatarUrl = ApiService.avatarUrl(_avatarFilename);

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
              const SizedBox(height: 10),
              Text(fullName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87)),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.description_outlined,
                      size: 18, color: Colors.black45),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DOCUMENT',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.black38,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                      Text(docType,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
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

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.88,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_outlined, color: _green),
                    const SizedBox(width: 8),
                    const Text('Notifications',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (_notifCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$_notifCount new',
                            style: const TextStyle(
                                color: Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: (_requests.isEmpty && _readyForPickup.isEmpty)
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none,
                                size: 48, color: Colors.black26),
                            SizedBox(height: 10),
                            Text('No notifications',
                                style: TextStyle(
                                    color: Colors.black38, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView(
                        controller: scrollCtrl,
                        children: [
                          // ── Ready for pickup (from completed_documents) ──
                          ..._readyForPickup.map((d) {
                            final doc  = d as Map<String, dynamic>;
                            final id   = doc['_id']?.toString() ?? '';
                            final isRead = _readNotifIds.contains(id);
                            final docType   = doc['documentType'] as String? ?? '—';
                            final claimCode = doc['claimCode']    as String? ?? '';
                            final time = _timeAgo(
                                doc['completedAt'] as String? ??
                                doc['createdAt']   as String? ?? '');
                            return InkWell(
                              onTap: () {
                                _markAsRead(id);
                                _showPickupDetail(doc);
                              },
                              child: Container(
                                color: isRead
                                    ? Colors.transparent
                                    : const Color(0xFFE8F5E9),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.green
                                          .withValues(alpha: isRead ? 0.08 : 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.storefront_outlined,
                                        color: isRead
                                            ? Colors.green.withValues(alpha: 0.5)
                                            : Colors.green,
                                        size: 20),
                                  ),
                                  title: Text(docType,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isRead
                                              ? FontWeight.w500
                                              : FontWeight.w700,
                                          color: isRead
                                              ? Colors.black45
                                              : Colors.black87)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Ready for Pickup • $time',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: isRead
                                                  ? Colors.black38
                                                  : Colors.green,
                                              fontWeight: isRead
                                                  ? FontWeight.normal
                                                  : FontWeight.w600)),
                                      if (claimCode.isNotEmpty)
                                        Text('Code: $claimCode',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: isRead
                                                    ? Colors.black38
                                                    : const Color(0xFF1A6B1A),
                                                letterSpacing: 1.5)),
                                    ],
                                  ),
                                  trailing: isRead
                                      ? null
                                      : Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle),
                                        ),
                                ),
                              ),
                            );
                          }),

                          // ── Claimed / Picked up ──────────────────────
                          ..._claimedDocuments.map((d) {
                            final doc    = d as Map<String, dynamic>;
                            final id     = doc['_id']?.toString() ?? '';
                            final isRead = _readNotifIds.contains(id);
                            final docType = doc['documentType'] as String? ?? '—';
                            final time    = _timeAgo(
                                doc['updatedAt'] as String? ??
                                doc['createdAt'] as String? ?? '');
                            return InkWell(
                              onTap: () => _markAsRead(id),
                              child: Container(
                                color: isRead
                                    ? Colors.transparent
                                    : const Color(0xFFE3F2FD),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.blue
                                          .withValues(alpha: isRead ? 0.08 : 0.18),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.check_circle_rounded,
                                        color: isRead
                                            ? Colors.blue.withValues(alpha: 0.4)
                                            : Colors.blue,
                                        size: 20),
                                  ),
                                  title: Text(docType,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isRead
                                              ? FontWeight.w500
                                              : FontWeight.w700,
                                          color: isRead
                                              ? Colors.black45
                                              : Colors.black87)),
                                  subtitle: Text(
                                    'Document picked up • $time',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isRead
                                            ? Colors.black38
                                            : Colors.blue,
                                        fontWeight: isRead
                                            ? FontWeight.normal
                                            : FontWeight.w600),
                                  ),
                                  trailing: isRead
                                      ? null
                                      : Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle),
                                        ),
                                ),
                              ),
                            );
                          }),

                          if ((_readyForPickup.isNotEmpty ||
                                  _claimedDocuments.isNotEmpty) &&
                              _requests.isNotEmpty)
                            const Divider(height: 1),

                          // ── Regular requests ─────────────────────────
                          ..._requests.map((r) {
                            final req  = r as Map<String, dynamic>;
                            final id   = req['_id']?.toString() ?? '';
                            final isRead = _readNotifIds.contains(id);
                            final status  = req['status']  as String? ?? 'Pending';
                            final docType = req['documentType'] as String? ??
                                req['title'] as String? ?? '—';
                            final time  = _timeAgo(req['createdAt'] as String? ?? '');
                            final color = _statusColor(status);
                            final needsAttention =
                                status == 'Rejected' && !isRead;
                            final icon = status == 'Rejected'
                                ? Icons.cancel_outlined
                                : status == 'Processing'
                                    ? Icons.hourglass_empty_outlined
                                    : Icons.pending_outlined;
                            return Column(
                              children: [
                                InkWell(
                                  onTap: () => _markAsRead(id),
                                  child: ListTile(
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color.withValues(
                                            alpha: isRead ? 0.06 : 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(icon,
                                          color: isRead
                                              ? color.withValues(alpha: 0.4)
                                              : color,
                                          size: 20),
                                    ),
                                    title: Text(docType,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: needsAttention
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isRead
                                                ? Colors.black38
                                                : Colors.black87)),
                                    subtitle: Text(
                                      '$status • $time',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: needsAttention
                                              ? color
                                              : Colors.black38),
                                    ),
                                    trailing: needsAttention
                                        ? Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle),
                                          )
                                        : null,
                                  ),
                                ),
                                const Divider(
                                    height: 1, indent: 72, endIndent: 16),
                              ],
                            );
                          }),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
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
