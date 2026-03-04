import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'moderator_user_details_screen.dart';

enum _FilterMode { all, overdue, active }

class ModeratorScreen extends StatefulWidget {
  const ModeratorScreen({super.key});

  @override
  State<ModeratorScreen> createState() => _ModeratorScreenState();
}

class _ModeratorScreenState extends State<ModeratorScreen> {
  Timer? _ticker;

  _FilterMode _filter = _FilterMode.overdue; // default: overdue first
  String _search = "";

  @override
  void initState() {
    super.initState();
    // 1s ticker so “OVERDUE” updates live
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ---------- Logic helpers ----------
  DateTime? _parseIso(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  bool _computeOverdue(Map<String, dynamic> d) {
    final tripActive = d['tripActive'] == true;
    final isOverdueFlag = d['isOverdue'] == true;
    if (isOverdueFlag) return true;

    final eta = _parseIso(d['etaIso']);
    if (!tripActive || eta == null) return false;
    return DateTime.now().isAfter(eta);
  }

  String _formatDelta(Duration d) {
    final neg = d.isNegative;
    final dd = neg ? d.abs() : d;
    final h = dd.inHours;
    final m = dd.inMinutes.remainder(60);
    final s = dd.inSeconds.remainder(60);
    String two(int x) => x.toString().padLeft(2, '0');
    if (h > 0) return '${neg ? "-" : ""}${h}h ${two(m)}m';
    return '${neg ? "-" : ""}${two(m)}m ${two(s)}s';
  }

  String _formatLocationTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      final days = diff.inDays;
      return '$days day${days > 1 ? 's' : ''} ago';
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    
    // Verify user is authenticated before querying
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF02050A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF02050A),
          elevation: 0,
          centerTitle: false,
          title: const Text(
            "Moderator",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha:0.28),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha:0.6)),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 34),
                SizedBox(height: 10),
                Text(
                  "Authentication Error",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 6),
                Text(
                  "You must be signed in to access Moderator. Please restart the app.",
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    final tripsQuery = FirebaseFirestore.instance.collection('trips');

    return Scaffold(
      backgroundColor: const Color(0xFF02050A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF02050A),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Moderator",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: tripsQuery.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _errorState("${snap.error}");
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rows = snap.data!.docs.map((doc) {
            final d = doc.data();
            final active = d['tripActive'] == true;
            final overdue = _computeOverdue(d);
            final eta = _parseIso(d['etaIso']);
            final ack = d['overdueAcknowledged'] == true;
            return _TripRow(
              id: doc.id,
              data: d,
              active: active,
              overdue: overdue,
              eta: eta,
              overdueAck: ack,
            );
          }).toList();

          // We only show "active trips" in the list, but keep ALL filter available if you want later.
          final activeTrips = rows.where((r) => r.active).toList();

          final overdueCount = activeTrips.where((r) => r.overdue).length;
          final activeCount = activeTrips.length;

          // Sort: overdue first, then soonest ETA
          activeTrips.sort((a, b) {
            if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
            if (a.eta == null && b.eta == null) return 0;
            if (a.eta == null) return 1;
            if (b.eta == null) return -1;
            return a.eta!.compareTo(b.eta!);
          });

          // Filter by mode
          List<_TripRow> filtered = switch (_filter) {
            _FilterMode.all => activeTrips,
            _FilterMode.overdue => activeTrips.where((r) => r.overdue).toList(),
            _FilterMode.active => activeTrips.where((r) => !r.overdue).toList(),
          };

          // Search filter (name or ramp)
          final q = _search.trim().toLowerCase();
          if (q.isNotEmpty) {
            filtered = filtered.where((r) {
              final d = r.data;
              final name = (d['name'] ?? d['userName'] ?? '').toString().toLowerCase();
              final ramp = (d['rampName'] ?? d['rampId'] ?? '').toString().toLowerCase();
              return name.contains(q) || ramp.contains(q);
            }).toList();
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 18 + bottomPad),
            children: [
              _pageHeader(overdueCount: overdueCount, activeCount: activeCount),
              const SizedBox(height: 10),

              _searchBar(
                value: _search,
                onChanged: (v) => setState(() => _search = v),
                onClear: () => setState(() => _search = ""),
              ),
              const SizedBox(height: 10),

              _dashboardTiles(
                overdueCount: overdueCount,
                activeCount: activeCount,
                selected: _filter,
                onSelect: (m) => setState(() => _filter = m),
              ),
              const SizedBox(height: 12),

              if (filtered.isEmpty) _emptyState(_filter, _search),

              for (final r in filtered) ...[
                _tripCard(context, r),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _pageHeader({required int overdueCount, required int activeCount}) {
    final total = activeCount;
    final text = total == 0
        ? "No active trips right now."
        : overdueCount > 0
        ? "$overdueCount overdue • $total active trips"
        : "$total active trips • none overdue";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.radar_rounded, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Live Trip Monitor",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar({
    required String value,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Colors.white54),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Search by name or ramp…",
                hintStyle: TextStyle(color: Colors.white38),
                isDense: true,
                border: InputBorder.none,
              ),
              onChanged: onChanged,
              controller: TextEditingController(text: value)
                ..selection = TextSelection.collapsed(offset: value.length),
            ),
          ),
          if (value.trim().isNotEmpty)
            IconButton(
              tooltip: "Clear",
              icon: const Icon(Icons.close_rounded, color: Colors.white54),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }

  Widget _dashboardTiles({
    required int overdueCount,
    required int activeCount,
    required _FilterMode selected,
    required ValueChanged<_FilterMode> onSelect,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            title: "OVERDUE",
            value: overdueCount.toString(),
            icon: Icons.warning_rounded,
            color: overdueCount > 0 ? Colors.redAccent : Colors.white54,
            selected: selected == _FilterMode.overdue,
            onTap: () => onSelect(_FilterMode.overdue),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            title: "ACTIVE",
            value: activeCount.toString(),
            icon: Icons.directions_boat_rounded,
            color: Colors.greenAccent,
            selected: selected == _FilterMode.active,
            onTap: () => onSelect(_FilterMode.active),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: _statTile(
            title: "ALL",
            value: "",
            icon: Icons.list_alt_rounded,
            color: Colors.white70,
            selected: selected == _FilterMode.all,
            onTap: () => onSelect(_FilterMode.all),
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha:0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.white24, width: selected ? 1.4 : 1),
          boxShadow: selected
              ? [
            BoxShadow(
              color: color.withValues(alpha:0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            )
          ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha:0.55)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  if (value.isNotEmpty)
                    Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900))
                  else
                    Text("Tap", style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripCard(BuildContext context, _TripRow r) {
    final d = r.data;

    final name = (d['name'] ?? d['userName'] ?? 'Unknown').toString();
    final rampName = (d['rampName'] ?? d['rampId'] ?? 'Unknown ramp').toString();
    final personsOnBoard = (d['personsOnBoard'] ?? '—').toString();

    final eta = r.eta;
    final now = DateTime.now();

    final subtitle = eta == null
        ? "ETA: —"
        : r.overdue
        ? "OVERDUE by ${_formatDelta(now.difference(eta))}"
        : "ETA in ${_formatDelta(eta.difference(now))}";

    final statusColor = r.overdue ? Colors.redAccent : Colors.greenAccent;

    // Extract last known location for overdue trips
    final lastLocation = d['lastLocation'] as Map<String, dynamic>?;
    final hasLocation = lastLocation != null && 
                       lastLocation['lat'] != null && 
                       lastLocation['lng'] != null;
    final lastLocationTime = hasLocation && lastLocation['timestamp'] != null
        ? _parseIso(lastLocation['timestamp'])
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ModeratorUserDetailsScreen(tripId: r.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha:0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: r.overdue ? Colors.redAccent : Colors.white24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left status + icon column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pill(
                  r.overdue ? "OVERDUE" : "ACTIVE",
                  statusColor,
                  icon: r.overdue ? Icons.warning_rounded : Icons.check_circle_rounded,
                ),
                const SizedBox(height: 8),
                if (r.overdue)
                  _miniPill(
                    r.overdueAck ? "ACK: YES" : "ACK: NO",
                    r.overdueAck ? Colors.greenAccent : Colors.white54,
                    icon: r.overdueAck ? Icons.verified_rounded : Icons.help_rounded,
                  ),
              ],
            ),

            const SizedBox(width: 12),

            // Main info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rampName,
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // ETA row
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 16, color: r.overdue ? Colors.redAccent : Colors.white54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: r.overdue ? Colors.redAccent : Colors.white54,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // People on board row
                  Row(
                    children: [
                      const Icon(Icons.groups_rounded, size: 16, color: Colors.white54),
                      const SizedBox(width: 6),
                      Text(
                        "People on board: $personsOnBoard",
                        style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ],
                  ),
                  
                  // Last known location (for overdue trips)
                  if (r.overdue) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          hasLocation ? Icons.location_on_rounded : Icons.location_off_rounded,
                          size: 16,
                          color: hasLocation ? Colors.orangeAccent : Colors.white54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hasLocation
                                ? "Last location: ${lastLocation!['lat'].toStringAsFixed(4)}, ${lastLocation['lng'].toStringAsFixed(4)}"
                                : "No location available",
                            style: TextStyle(
                              color: hasLocation ? Colors.orangeAccent : Colors.white54,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (hasLocation && lastLocationTime != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 22), // Align with location icon
                          Text(
                            "Updated: ${_formatLocationTime(lastLocationTime)}",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(_FilterMode mode, String search) {
    final searching = search.trim().isNotEmpty;

    String title;
    String subtitle;

    if (searching) {
      title = "No matches";
      subtitle = "Try a different name or ramp.";
    } else {
      switch (mode) {
        case _FilterMode.overdue:
          title = "All clear";
          subtitle = "No overdue trips right now.";
          break;
        case _FilterMode.active:
          title = "No active trips";
          subtitle = "Trips will show here once someone starts one.";
          break;
        case _FilterMode.all:
          title = "Nothing to show";
          subtitle = "No active trips right now.";
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(
              searching ? Icons.search_off_rounded : Icons.inbox_rounded,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String err) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha:0.28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withValues(alpha:0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 34),
            const SizedBox(height: 10),
            const Text(
              "Firestore error",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              err,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _pill(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static Widget _miniPill(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha:0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TripRow {
  final String id;
  final Map<String, dynamic> data;
  final bool active;
  final bool overdue;
  final DateTime? eta;
  final bool overdueAck;

  _TripRow({
    required this.id,
    required this.data,
    required this.active,
    required this.overdue,
    required this.eta,
    required this.overdueAck,
  });
}
