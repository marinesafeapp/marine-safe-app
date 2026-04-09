import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/user_profile_service.dart';
import '../services/vessels_service.dart';
import '../services/expiry_notification_scheduler.dart';
import '../models/vessel.dart';
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
  List<Vessel> _vessels = <Vessel>[];
  String? _selectedVesselId;
  String? _selectedVesselName;

  static const Color _bg = Color(0xFF02050A);
  static const Color _accent = Color(0xFF2CB6FF);
  static const String _kDefaultVesselKey = '__default_vessel__';

  String? _selectedDropdownKey;

  bool _expandedPfds = false;
  bool _expandedEpirb = false;
  bool _expandedFlares = false;
  bool _expandedExtinguisher = false;

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
      _vessels = vessels;
      // If a valid vessel is selected, use it; otherwise fall back to default boat safety record.
      final hasMatch = vesselId != null &&
          vesselId.isNotEmpty &&
          vessels.any((v) => v.id == vesselId);
      if (hasMatch) {
        for (final v in vessels) {
          if (v.id == vesselId) {
            _selectedVesselName = (v.name.isEmpty ? 'Unnamed vessel' : v.name);
            break;
          }
        }
        _selectedVesselId = vesselId;
        _selectedDropdownKey = vesselId;
        _hasValidSelectedVessel = true;
      } else {
        // Default boat (no specific vessel)
        vesselId = null;
        _selectedVesselId = null;
        _selectedVesselName = 'Default boat';
        _selectedDropdownKey = _kDefaultVesselKey;
        _hasValidSelectedVessel = true;
      }
    } else {
      _hasValidSelectedVessel = true;
      _vessels = <Vessel>[];
      _selectedVesselId = null;
      _selectedVesselName = null;
      _selectedDropdownKey = null;
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

  /// Strip-style section matching home page / boat details: accent container, icon, label, value, chevron.
  Widget _expansionSection({
    required String title,
    required IconData icon,
    required String value,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
    Color? valueColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    Icon(icon, color: valueColor ?? _accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            style: TextStyle(
                              color: valueColor ?? Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white54,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    // Pro with no vessel selected or selected vessel not in list: prompt to add/select in Boat Details.
    if (_isPro && !_hasValidSelectedVessel) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          title: const Text(
            'Safety Equipment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Add or select a vessel in Boat Details to manage its safety gear.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text(
          'Safety Equipment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isPro && _vessels.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  Icon(Icons.directions_boat_rounded, color: _accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Vessel safety record',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDropdownKey,
                            dropdownColor: Colors.black87,
                            iconEnabledColor: Colors.white70,
                            hint: const Text(
                              'Select vessel',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            items: _vessels.map((v) {
                              final name = v.name.isEmpty ? 'Unnamed vessel' : v.name;
                              return DropdownMenuItem<String>(
                                value: v.id,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }).toList()
                              ..insert(
                                0,
                                const DropdownMenuItem<String>(
                                  value: _kDefaultVesselKey,
                                  child: Text(
                                    'Default boat',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            onChanged: (value) async {
                              if (value == null) return;
                              if (value == _kDefaultVesselKey) {
                                await VesselsService.instance.setSelectedVesselId(null);
                              } else {
                                await VesselsService.instance.setSelectedVesselId(value);
                              }
                              if (!mounted) return;
                              setState(() {
                                _loading = true;
                              });
                              await _load();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          _expansionSection(
            title: 'Life jackets (PFDs)',
            icon: Icons.health_and_safety_rounded,
            value: _pfds.isEmpty ? 'Add life jacket' : '${_pfds.length} jacket${_pfds.length == 1 ? '' : 's'}',
            expanded: _expandedPfds,
            onToggle: () => setState(() => _expandedPfds = !_expandedPfds),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: _accent),
                      onPressed: () => setState(() {
                        _pfds.add(_PfdEntry(
                          id: 'pfd_${DateTime.now().millisecondsSinceEpoch}',
                        ));
                      }),
                    ),
                  ],
                ),
                if (_pfds.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No life jackets added. Tap + to add one.',
                      style: TextStyle(color: Colors.white54),
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
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Inspection due', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              subtitle: Text(
                                _fmt(pfd.inspectionDue),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _dateColor(pfd.inspectionDue) ?? Colors.white,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.calendar_today, size: 20, color: _accent),
                                    onPressed: () async {
                                      final d = await _pickDate(pfd.inspectionDue);
                                      if (d != null) setState(() => pfd.inspectionDue = d);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white54),
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
          const SizedBox(height: 16),
          _expansionSection(
            title: 'EPIRB battery expiry',
            icon: Icons.satellite_alt_rounded,
            value: _fmt(_epirbExpiry),
            valueColor: _dateColor(_epirbExpiry),
            expanded: _expandedEpirb,
            onToggle: () => setState(() => _expandedEpirb = !_expandedEpirb),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _fmt(_epirbExpiry),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _dateColor(_epirbExpiry) ?? Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: _accent),
                  onPressed: () async {
                    final d = await _pickDate(_epirbExpiry);
                    if (d != null) setState(() => _epirbExpiry = d);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _expansionSection(
            title: 'Flares expiry',
            icon: Icons.warning_amber_rounded,
            value: _fmt(_flaresExpiry),
            valueColor: _dateColor(_flaresExpiry),
            expanded: _expandedFlares,
            onToggle: () => setState(() => _expandedFlares = !_expandedFlares),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _fmt(_flaresExpiry),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _dateColor(_flaresExpiry) ?? Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: _accent),
                  onPressed: () async {
                    final d = await _pickDate(_flaresExpiry);
                    if (d != null) setState(() => _flaresExpiry = d);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _expansionSection(
            title: 'Fire extinguisher',
            icon: Icons.local_fire_department_rounded,
            value: _extinguisherPresent ? _fmt(_extinguisherExpiry) : 'Not onboard',
            valueColor: _dateColor(_extinguisherExpiry),
            expanded: _expandedExtinguisher,
            onToggle: () => setState(() => _expandedExtinguisher = !_expandedExtinguisher),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  title: const Text('Onboard', style: TextStyle(color: Colors.white)),
                  value: _extinguisherPresent,
                  activeColor: _accent,
                  onChanged: (v) => setState(() => _extinguisherPresent = v),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Expiry: ${_fmt(_extinguisherExpiry)}',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _dateColor(_extinguisherExpiry) ?? Colors.white70),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, color: _accent),
                      onPressed: () async {
                        final d = await _pickDate(_extinguisherExpiry);
                        if (d != null) setState(() => _extinguisherExpiry = d);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Save safety equipment',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
