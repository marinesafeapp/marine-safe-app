import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/user_profile_service.dart';
import '../services/vessels_service.dart';
import '../services/expiry_notification_scheduler.dart';
import 'boat_details_screen.dart';
import 'home/services/trip_prefs.dart';

class SafetyEquipmentScreen extends StatefulWidget {
  const SafetyEquipmentScreen({super.key});

  @override
  State<SafetyEquipmentScreen> createState() => _SafetyEquipmentScreenState();
}

class _PfdEntry {
  final String id;
  DateTime? inspectionDue;

  _PfdEntry({required this.id, this.inspectionDue});

  Map<String, dynamic> toJson() => {
        'id': id,
        'inspectionDue': inspectionDue?.toIso8601String(),
      };

  static _PfdEntry fromJson(Map<String, dynamic> m) {
    final iso = m['inspectionDue'];
    return _PfdEntry(
      id: m['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      inspectionDue: iso != null ? DateTime.tryParse(iso.toString()) : null,
    );
  }
}

class _SafetyEquipmentScreenState extends State<SafetyEquipmentScreen> {
  List<_PfdEntry> _pfds = [];
  DateTime? _epirbExpiry;
  DateTime? _flaresExpiry;
  bool _extinguisherPresent = true;
  DateTime? _extinguisherExpiry;

  bool _loading = true;
  bool _isPro = false;
  /// When Pro: true if user has at least one vessel and a selected vessel that exists in the list.
  bool _hasValidSelectedVessel = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isPro = await UserProfileService.instance.getIsPro();
    _isPro = isPro;
    String? vesselId;
    if (isPro) {
      vesselId = await VesselsService.instance.getSelectedVesselId();
      final vessels = await VesselsService.instance.getVessels();
      _hasValidSelectedVessel = vesselId != null &&
          vesselId.isNotEmpty &&
          vessels.any((v) => v.id == vesselId);
    } else {
      _hasValidSelectedVessel = true;
    }
    final json = await TripPrefs.getSafetyStateJsonForVessel(vesselId);

    if (json != null) {
      try {
        final Map<String, dynamic> state = jsonDecode(json);
        _extinguisherPresent = state['extinguisherPresent'] ?? true;

        if (state['pfds'] is List) {
          final list = state['pfds'] as List;
          _pfds = list
              .whereType<Map>()
              .map((m) => _PfdEntry.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        } else {
          // Migrate from old pfdCount + pfdInspectionDue
          final count = state['pfdCount'] as int? ?? 0;
          final singleDue = state['pfdInspectionDue'] != null
              ? DateTime.tryParse(state['pfdInspectionDue'].toString())
              : null;
          _pfds = List.generate(
            count.clamp(0, 99),
            (i) => _PfdEntry(
              id: 'pfd_${DateTime.now().millisecondsSinceEpoch}_$i',
              inspectionDue: singleDue,
            ),
          );
        }

        final epirbIso = state['epirbExpiry'];
        if (epirbIso != null) {
          _epirbExpiry = DateTime.tryParse(epirbIso);
        }

        final flaresIso = state['flaresExpiry'];
        if (flaresIso != null) {
          _flaresExpiry = DateTime.tryParse(flaresIso);
        }

        final extinguisherIso = state['extinguisherExpiry'];
        if (extinguisherIso != null) {
          _extinguisherExpiry = DateTime.tryParse(extinguisherIso);
        }
      } catch (_) {
        // ignore corrupt data – user can re-save
      }
    }

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final state = {
      'pfdCount': _pfds.length,
      'pfds': _pfds.map((e) => e.toJson()).toList(),
      'epirbExpiry': _epirbExpiry?.toIso8601String(),
      'flaresExpiry': _flaresExpiry?.toIso8601String(),
      'extinguisherPresent': _extinguisherPresent,
      'extinguisherExpiry': _extinguisherExpiry?.toIso8601String(),
    };

    final isPro = await UserProfileService.instance.getIsPro();
    final vesselId = isPro ? await VesselsService.instance.getSelectedVesselId() : null;
    await TripPrefs.saveSafetyStateJsonForVessel(vesselId, jsonEncode(state));
    await ExpiryNotificationScheduler.instance.scheduleAllExpiryNotifications();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Safety equipment saved')),
    );
  }

  Future<DateTime?> _pickDate(DateTime? current) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Not set';
    return DateFormat.yMMMd().format(d);
  }

  static const int _dueSoonDays = 30;

  bool _isOverdue(DateTime? d) {
    if (d == null) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return DateTime(d.year, d.month, d.day).isBefore(today);
  }

  bool _isDueSoon(DateTime? d) {
    if (d == null) return false;
    if (_isOverdue(d)) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final dateOnly = DateTime(d.year, d.month, d.day);
    final diff = dateOnly.difference(today).inDays;
    return diff >= 0 && diff <= _dueSoonDays;
  }

  Color? _dateColor(DateTime? d) {
    if (d == null) return null;
    if (_isOverdue(d)) return Colors.redAccent;
    if (_isDueSoon(d)) return Colors.orange;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Pro with no vessel selected or selected vessel not in list: prompt to add/select in Boat Details.
    if (_isPro && !_hasValidSelectedVessel) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Safety Equipment',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Add or select a vessel in Boat Details to manage its safety gear.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const BoatDetailsScreen(),
                      ),
                    ).then((_) => _load());
                  },
                  icon: const Icon(Icons.directions_boat),
                  label: const Text('Open Boat Details'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Safety Equipment',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ==========================
          // LIFE JACKETS (PFDs)
          // ==========================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Life jackets (PFDs)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_pfds.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() {
                          _pfds.add(_PfdEntry(
                            id: 'pfd_${DateTime.now().millisecondsSinceEpoch}',
                          ));
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_pfds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No life jackets added. Tap + to add one.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._pfds.asMap().entries.map((entry) {
                      final i = entry.key;
                      final pfd = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                'Jacket ${i + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Inspection due', style: TextStyle(fontSize: 12)),
                                subtitle: Text(
                                  _fmt(pfd.inspectionDue),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _dateColor(pfd.inspectionDue),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.calendar_today, size: 20),
                                      onPressed: () async {
                                        final d = await _pickDate(pfd.inspectionDue);
                                        if (d != null) {
                                          setState(() => pfd.inspectionDue = d);
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20),
                                      onPressed: () => setState(() => _pfds.removeWhere((e) => e.id == pfd.id)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // ==========================
          // EPIRB
          // ==========================
          Card(
            color: _dateColor(_epirbExpiry)?.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: _dateColor(_epirbExpiry) != null
                  ? BorderSide(color: _dateColor(_epirbExpiry)!, width: 1.5)
                  : BorderSide.none,
            ),
            child: ListTile(
              title: const Text('EPIRB battery expiry'),
              subtitle: Text(
                _fmt(_epirbExpiry),
                style: TextStyle(fontWeight: FontWeight.w700, color: _dateColor(_epirbExpiry)),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final d = await _pickDate(_epirbExpiry);
                  if (d != null) setState(() => _epirbExpiry = d);
                },
              ),
            ),
          ),

          // ==========================
          // FLARES
          // ==========================
          Card(
            color: _dateColor(_flaresExpiry)?.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: _dateColor(_flaresExpiry) != null
                  ? BorderSide(color: _dateColor(_flaresExpiry)!, width: 1.5)
                  : BorderSide.none,
            ),
            child: ListTile(
              title: const Text('Flares expiry'),
              subtitle: Text(
                _fmt(_flaresExpiry),
                style: TextStyle(fontWeight: FontWeight.w700, color: _dateColor(_flaresExpiry)),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final d = await _pickDate(_flaresExpiry);
                  if (d != null) setState(() => _flaresExpiry = d);
                },
              ),
            ),
          ),

          // ==========================
          // FIRE EXTINGUISHER
          // ==========================
          Card(
            color: _dateColor(_extinguisherExpiry)?.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: _dateColor(_extinguisherExpiry) != null
                  ? BorderSide(color: _dateColor(_extinguisherExpiry)!, width: 1.5)
                  : BorderSide.none,
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Fire extinguisher onboard'),
                  value: _extinguisherPresent,
                  onChanged: (v) => setState(() => _extinguisherPresent = v),
                ),
                ListTile(
                  title: const Text('Expiry date'),
                  subtitle: Text(
                    _fmt(_extinguisherExpiry),
                    style: TextStyle(fontWeight: FontWeight.w700, color: _dateColor(_extinguisherExpiry)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final d = await _pickDate(_extinguisherExpiry);
                      if (d != null) setState(() => _extinguisherExpiry = d);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ==========================
          // SAVE
          // ==========================
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'SAVE SAFETY EQUIPMENT',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
