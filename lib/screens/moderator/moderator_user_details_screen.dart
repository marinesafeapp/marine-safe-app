import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ModeratorUserDetailsScreen extends StatelessWidget {
  final String tripId;

  const ModeratorUserDetailsScreen({
    super.key,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);

    return Scaffold(
      backgroundColor: const Color(0xFF02050A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF02050A),
        elevation: 0,
        title: const Text(
          "Trip Details",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: tripRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _errorState("${snap.error}");
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(
              child: Text('Trip not found', style: TextStyle(color: Colors.white70)),
            );
          }

          final d = snap.data!.data()!;
          final uid = (d['uid'] ?? '').toString();

          final tripActive = d['tripActive'] == true;
          final isOverdue = d['isOverdue'] == true;
          final overdueAck = d['overdueAcknowledged'] == true;

          final rampName = (d['rampName'] ?? d['rampId'] ?? '—').toString();
          final personsOnBoard = (d['personsOnBoard'] ?? '—').toString();

          final departAt = _parseDate(d['departAtIso']);
          final eta = _parseDate(d['etaIso']);

          final statusText = isOverdue
              ? "OVERDUE"
              : (tripActive ? "ACTIVE" : "ENDED");
          final statusColor = isOverdue
              ? Colors.redAccent
              : (tripActive ? Colors.greenAccent : Colors.white54);

          final headerLine = eta == null
              ? "ETA: —"
              : isOverdue
              ? "OVERDUE since ${_fmtDateTime(eta)}"
              : "ETA: ${_fmtDateTime(eta)}";

          final totalOverdue = (isOverdue && eta != null)
              ? _formatDuration(DateTime.now().difference(eta))
              : null;

          // Pull profile from users collection (what user entered on phone)
          final userRef = uid.isEmpty
              ? null
              : FirebaseFirestore.instance.collection('users').doc(uid);

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 24 + bottomPad),
                  children: [
                    _headerCard(
                      title: "Live Trip Summary",
                      subtitle: headerLine,
                      leftIcon: isOverdue ? Icons.warning_rounded : Icons.radar_rounded,
                      pill1: _pill(statusText, statusColor,
                          icon: isOverdue ? Icons.warning_rounded : Icons.check_circle_rounded),
                      pill2: isOverdue
                          ? _miniPill(
                        overdueAck ? "ACK: YES" : "ACK: NO",
                        overdueAck ? Colors.greenAccent : Colors.white54,
                        icon: overdueAck ? Icons.verified_rounded : Icons.help_rounded,
                      )
                          : null,
                      lines: [
                        _infoRow(Icons.place_rounded, "Ramp", rampName),
                        _infoRow(Icons.groups_rounded, "People on board", personsOnBoard.toString()),
                        _infoRow(Icons.directions_boat_rounded, "Trip", tripActive ? "Active" : "Ended"),
                        if (totalOverdue != null)
                          _infoRow(Icons.schedule_rounded, "Total time overdue", totalOverdue),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // USER PROFILE (from users collection)
                    if (userRef == null)
                      _sectionCard(
                        title: "User Profile",
                        children: const [
                          Text(
                            "No UID on this trip record yet.",
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                          ),
                        ],
                      )
                    else
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: userRef.snapshots(),
                        builder: (context, uSnap) {
                          if (uSnap.hasError) {
                            return _sectionCard(
                              title: "User Profile",
                              children: [
                                Text(
                                  "User fetch error: ${uSnap.error}",
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            );
                          }
                          if (!uSnap.hasData) {
                            return _sectionCard(
                              title: "User Profile",
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                              ],
                            );
                          }

                          final ud = uSnap.data!.data() ?? <String, dynamic>{};

                          final displayName = (ud['displayName'] ?? d['name'] ?? '—').toString();
                          final email = (ud['email'] ?? d['email'] ?? '—').toString();
                          final phone = (ud['phone'] ?? '—').toString();

                          final emergencyName = (ud['emergencyName'] ?? '—').toString();
                          final emergencyPhone = (ud['emergencyPhone'] ?? '—').toString();

                          // A few safety highlights (only show if present)
                          final flaresExpiry = _parseDate(ud['flaresExpiry']);
                          final extinguisherDue = _parseDate(ud['extinguisherServiceDue']);
                          final epirbExpiry = _parseDate(ud['epirbBatteryExpiry']);
                          final pfdCount = (ud['pfdCount'] ?? '').toString();

                          return Column(
                            children: [
                              _sectionCard(
                                title: "User Profile",
                                children: [
                                  _kv("Name", displayName),
                                  _kv("Phone", phone),
                                  _kv("Email", email),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _sectionCard(
                                title: "Emergency Contact",
                                children: [
                                  _kv("Name", emergencyName),
                                  _kv("Phone", emergencyPhone),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _sectionCard(
                                title: "Safety (Quick View)",
                                children: [
                                  _kv("PFD count", pfdCount.isEmpty ? "—" : pfdCount),
                                  _kv("Flares expiry", flaresExpiry == null ? "—" : _fmtDate(flaresExpiry)),
                                  _kv("Extinguisher due", extinguisherDue == null ? "—" : _fmtDate(extinguisherDue)),
                                  _kv("EPIRB battery", epirbExpiry == null ? "—" : _fmtDate(epirbExpiry)),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                    const SizedBox(height: 12),

                    // TRIP DETAILS (raw but nicely formatted)
                    _sectionCard(
                      title: "Trip Details",
                      children: [
                        _kv("Depart", departAt == null ? "—" : _fmtDateTime(departAt)),
                        _kv("Return ETA", eta == null ? "—" : _fmtDateTime(eta)),
                        _kv("Ramp ID", (d['rampId'] ?? '—').toString()),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // LAST KNOWN LOCATION (for overdue trips)
                    if (isOverdue) _buildLastLocationSection(context, d),
                  ],
                ),
              ),

                // Bottom action bar (End Trip)
                _bottomBar(
                  context,
                  tripRef: tripRef,
                  tripActive: tripActive,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------- Bottom bar ----------
  Widget _bottomBar(
      BuildContext context, {
        required DocumentReference<Map<String, dynamic>> tripRef,
        required bool tripActive,
      }) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 14 + bottom),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.5),
        border: const Border(
          top: BorderSide(color: Colors.white12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: tripActive
                  ? () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF0B111A),
                    title: const Text("End trip?", style: TextStyle(color: Colors.white)),
                    content: const Text(
                      "This will mark the trip as ended (tripActive = false).",
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("End Trip", style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );

                if (ok != true) return;

                final now = DateTime.now();
                await tripRef.set({
                  'tripActive': false,
                  'isOverdue': false,
                  'overdueAcknowledged': true,
                  'endedAtIso': now.toIso8601String(),
                  'updatedAt': now.toIso8601String(),
                  'updatedAtMs': now.millisecondsSinceEpoch,
                }, SetOptions(merge: true));

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Trip ended ✅")),
                );
              }
                  : null,
              icon: const Icon(Icons.stop_circle_rounded),
              label: Text(tripActive ? "End Trip" : "Trip Ended"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha:tripActive ? 1 : 0.3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- UI blocks ----------
  static Widget _headerCard({
    required String title,
    required String subtitle,
    required IconData leftIcon,
    required Widget pill1,
    Widget? pill2,
    required List<Widget> lines,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(leftIcon, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    pill1,
                    if (pill2 != null) pill2,
                  ],
                ),
                const SizedBox(height: 12),
                ...lines,
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              )),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(k, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  static Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white54),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
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
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
        ],
      ),
    );
  }

  static Widget _errorState(String err) {
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
            Text(err, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ---------- Date helpers ----------
  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static String _fmtDate(DateTime d) {
    final x = d.toLocal();
    return "${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}";
  }

  static String _fmtDateTime(DateTime d) {
    final x = d.toLocal();
    final hh = x.hour.toString().padLeft(2, '0');
    final mm = x.minute.toString().padLeft(2, '0');
    return "${_fmtDate(x)} $hh:$mm";
  }

  static String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    parts.add('${minutes}m');
    return parts.join(' ');
  }

  // ---------- Last Location Section ----------
  Widget _buildLastLocationSection(BuildContext context, Map<String, dynamic> tripData) {
    final lastLocation = tripData['lastLocation'] as Map<String, dynamic>?;
    final hasLocation = lastLocation != null &&
                       lastLocation['lat'] != null &&
                       lastLocation['lng'] != null;

    if (!hasLocation) {
      return _sectionCard(
        title: "Last Known Location",
        children: [
          const Row(
            children: [
              Icon(Icons.location_off_rounded, color: Colors.white54, size: 20),
              SizedBox(width: 8),
              Text(
                "No location available",
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Location data will appear here once GPS tracking updates.",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );
    }

    final lat = (lastLocation!['lat'] as num).toDouble();
    final lng = (lastLocation['lng'] as num).toDouble();
    final locationTime = _parseDate(lastLocation['timestamp']);
    final accuracy = lastLocation['accuracy'] as double?;
    final speed = lastLocation['speed'] as double?;
    final heading = lastLocation['heading'] as double?;

    final locationAge = locationTime != null
        ? _formatLocationAge(DateTime.now().difference(locationTime))
        : 'Unknown';

    return Column(
      children: [
        _sectionCard(
          title: "Last Known Location",
          children: [
            // Map view
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 15.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'au.com.marinesafe.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lng),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.redAccent,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Coordinates
            _kv("Latitude", lat.toStringAsFixed(6)),
            _kv("Longitude", lng.toStringAsFixed(6)),
            if (locationTime != null)
              _kv("Last updated", "${_fmtDateTime(locationTime)} ($locationAge)"),
            if (accuracy != null)
              _kv("Accuracy", "${accuracy.toStringAsFixed(1)} m"),
            if (speed != null)
              _kv("Speed", "${(speed * 3.6).toStringAsFixed(1)} km/h"), // Convert m/s to km/h
            if (heading != null)
              _kv("Heading", "${heading.toStringAsFixed(0)}°"),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _copyCoordinates(context, lat, lng),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text("Copy Coords"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withValues(alpha:0.2),
                      foregroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blueAccent.withValues(alpha:0.5)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openInGoogleMaps(lat, lng),
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text("Open Maps"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.withValues(alpha:0.2),
                      foregroundColor: Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.greenAccent.withValues(alpha:0.5)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _copyCoordinates(BuildContext context, double lat, double lng) async {
    final coords = "$lat, $lng";
    await Clipboard.setData(ClipboardData(text: coords));
    
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Coordinates copied: $coords"),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  Future<void> _openInGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static String _formatLocationAge(Duration d) {
    if (d.inMinutes < 1) {
      return 'Just now';
    } else if (d.inMinutes < 60) {
      return '${d.inMinutes}m ago';
    } else if (d.inHours < 24) {
      return '${d.inHours}h ago';
    } else {
      final days = d.inDays;
      return '$days day${days > 1 ? 's' : ''} ago';
    }
  }
}
