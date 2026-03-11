import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vessel.dart';
import '../services/expiry_notification_scheduler.dart';
import '../services/user_profile_service.dart';
import '../services/vessels_service.dart';
import 'safety_equipment_screen.dart';

class BoatDetailsScreen extends StatefulWidget {
  const BoatDetailsScreen({super.key});

  @override
  State<BoatDetailsScreen> createState() => _BoatDetailsScreenState();
}

class _BoatDetailsScreenState extends State<BoatDetailsScreen> {
  final TextEditingController _boatNameCtrl = TextEditingController();
  final TextEditingController _regoCtrl = TextEditingController();
  final TextEditingController _trailerCtrl = TextEditingController();

  DateTime? _boatRegoExpiry;
  DateTime? _trailerRegoExpiry;

  bool _loaded = false;
  bool _saving = false;
  bool _isPro = false;
  List<Vessel> _vessels = [];

  static const Color _bg = Color(0xFF02050A);
  static const Color _accent = Color(0xFF2CB6FF);

  static const String _kBoatName = 'profile.boatName';
  static const String _kBoatRego = 'profile.boatRego';
  static const String _kTrailerRego = 'profile.trailerRego';
  static const String _kBoatRegoExpiry = 'profile.boatRegoExpiry';
  static const String _kTrailerRegoExpiry = 'profile.trailerRegoExpiry';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _boatNameCtrl.dispose();
    _regoCtrl.dispose();
    _trailerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _boatNameCtrl.text = p.getString(_kBoatName) ?? '';
    _regoCtrl.text = p.getString(_kBoatRego) ?? '';
    _trailerCtrl.text = p.getString(_kTrailerRego) ?? '';
    _boatRegoExpiry = _parseIso(p.getString(_kBoatRegoExpiry));
    _trailerRegoExpiry = _parseIso(p.getString(_kTrailerRegoExpiry));
    _isPro = await UserProfileService.instance.getIsPro();
    _vessels = await VesselsService.instance.getVessels();
    if (mounted) setState(() => _loaded = true);
  }

  static DateTime? _parseIso(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static Future<void> _setIsoOrRemove(SharedPreferences p, String key, DateTime? value) async {
    if (value == null) {
      await p.remove(key);
    } else {
      await p.setString(key, value.toIso8601String());
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBoatName, _boatNameCtrl.text.trim());
    await p.setString(_kBoatRego, _regoCtrl.text.trim());
    await p.setString(_kTrailerRego, _trailerCtrl.text.trim());
    await _setIsoOrRemove(p, _kBoatRegoExpiry, _boatRegoExpiry);
    await _setIsoOrRemove(p, _kTrailerRegoExpiry, _trailerRegoExpiry);
    await ExpiryNotificationScheduler.instance.scheduleAllExpiryNotifications();
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Boat details saved"),
          backgroundColor: _accent.withValues(alpha:0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _fmtDate(DateTime d) {
    final local = d.toLocal();
    return "${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}";
  }

  bool _isDueWithinDays(DateTime? d, int days) {
    if (d == null) return false;
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    return diff >= 0 && diff <= days;
  }

  bool _isOverdue(DateTime? d) {
    if (d == null) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return d.isBefore(today);
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          "Boat details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: _loaded && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                : const Text("Save", style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2CB6FF))),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2CB6FF)))
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isPro) ...[
                    _sectionLabel("Vessels (Pro)"),
                    _card(
                      children: [
                        ..._vessels.map((v) => _vesselTile(v)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _addOrEditVessel,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text("Add vessel (boat, jet ski, etc.)"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accent,
                            side: BorderSide(color: _accent.withValues(alpha: 0.6)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  _sectionLabel(_isPro ? "Default boat (profile)" : "Boat & trailer"),
                  _card(
                    children: [
                      _textField(_boatNameCtrl, "Boat name", Icons.directions_boat_rounded),
                      const SizedBox(height: 12),
                      _textField(_regoCtrl, "Boat rego", Icons.badge_rounded),
                      _dateRow("Boat rego expiry", _boatRegoExpiry, (d) => setState(() => _boatRegoExpiry = d), () => setState(() => _boatRegoExpiry = null)),
                      const SizedBox(height: 12),
                      _textField(_trailerCtrl, "Trailer rego", Icons.badge_rounded),
                      _dateRow("Trailer rego expiry", _trailerRegoExpiry, (d) => setState(() => _trailerRegoExpiry = d), () => setState(() => _trailerRegoExpiry = null)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Save boat details", style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: _accent, size: 22),
        filled: true,
        fillColor: Colors.black.withValues(alpha:0.25),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _accent.withValues(alpha:0.6))),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'jet_ski': return Icons.two_wheeler_rounded;
      case 'other': return Icons.directions_boat_filled_rounded;
      default: return Icons.directions_boat_rounded;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'jet_ski': return 'Jet ski';
      case 'other': return 'Other';
      default: return 'Boat';
    }
  }

  Widget _vesselTile(Vessel v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconForType(v.type), color: _accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name.isEmpty ? 'Unnamed' : v.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(_labelForType(v.type), style: TextStyle(color: Colors.white54, fontSize: 12)),
                      if (v.boatRego.isNotEmpty) Text('Rego: ${v.boatRego}', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await VesselsService.instance.setSelectedVesselId(v.id);
                    if (!mounted) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyEquipmentScreen()));
                  },
                  icon: const Icon(Icons.health_and_safety_rounded, size: 18),
                  label: const Text('Safety gear'),
                  style: TextButton.styleFrom(foregroundColor: _accent),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await VesselsService.instance.setSelectedVesselId(v.id);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Select'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                ),
                TextButton.icon(
                  onPressed: () => _addOrEditVessel(vessel: v),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white54),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDeleteVessel(v),
                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade300),
                  label: Text('Delete', style: TextStyle(color: Colors.red.shade300)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteVessel(Vessel v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete vessel?'),
        content: Text('Remove "${v.name.isEmpty ? _labelForType(v.type) : v.name}"? Its safety gear data will remain until you add a vessel with the same ID.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: Colors.red.shade400))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await VesselsService.instance.deleteVessel(v.id);
      _vessels = await VesselsService.instance.getVessels();
      setState(() {});
    }
  }

  Future<void> _addOrEditVessel({Vessel? vessel}) async {
    final isEdit = vessel != null;
    final nameCtrl = TextEditingController(text: vessel?.name ?? '');
    final regoCtrl = TextEditingController(text: vessel?.boatRego ?? '');
    final trailerCtrl = TextEditingController(text: vessel?.trailerRego ?? '');
    String type = vessel?.type ?? 'boat';
    DateTime? boatExpiry = vessel?.boatRegoExpiry;
    DateTime? trailerExpiry = vessel?.trailerRegoExpiry;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: Colors.white24),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(isEdit ? 'Edit vessel' : 'Add vessel', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Jet ski, Tinny',
                      labelStyle: TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(type),
                    initialValue: type,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    dropdownColor: Colors.grey.shade900,
                    items: const [
                      DropdownMenuItem(value: 'boat', child: Text('Boat')),
                      DropdownMenuItem(value: 'jet_ski', child: Text('Jet ski')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => setModalState(() => type = v ?? 'boat'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: regoCtrl,
                    decoration: InputDecoration(
                      labelText: 'Boat rego',
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  _dateRowInSheet("Boat rego expiry", boatExpiry, (d) => setModalState(() => boatExpiry = d), () => setModalState(() => boatExpiry = null), setModalState),
                  const SizedBox(height: 12),
                  TextField(
                    controller: trailerCtrl,
                    decoration: InputDecoration(
                      labelText: 'Trailer rego',
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  _dateRowInSheet("Trailer rego expiry", trailerExpiry, (d) => setModalState(() => trailerExpiry = d), () => setModalState(() => trailerExpiry = null), setModalState),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            final id = vessel?.id ?? VesselsService.generateId();
                            final now = DateTime.now();
                            final newVessel = Vessel(
                              id: id,
                              name: name.isEmpty ? _labelForType(type) : name,
                              type: type,
                              boatRego: regoCtrl.text.trim(),
                              boatRegoExpiry: boatExpiry,
                              trailerRego: trailerCtrl.text.trim(),
                              trailerRegoExpiry: trailerExpiry,
                              createdAt: isEdit ? vessel!.createdAt : now,
                              updatedAt: now,
                            );
                            if (isEdit) {
                              await VesselsService.instance.updateVessel(newVessel);
                            } else {
                              await VesselsService.instance.addVessel(newVessel);
                              await VesselsService.instance.setSelectedVesselId(id);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _vessels = await VesselsService.instance.getVessels();
                            if (mounted) setState(() {});
                          },
                          child: Text(isEdit ? 'Save' : 'Add'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dateRowInSheet(String label, DateTime? value, ValueChanged<DateTime> onPicked, VoidCallback onClear, StateSetter setModalState) {
    final overdue = _isOverdue(value);
    final dueSoon = _isDueWithinDays(value, 30);
    Color? statusColor = overdue ? Colors.redAccent : (dueSoon ? Colors.orange : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, color: _accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(value == null ? 'Not set' : _fmtDate(value), style: TextStyle(color: statusColor ?? Colors.white, fontSize: 14)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _pickDate(current: value, onPicked: (d) { onPicked(d); setModalState(() {}); }),
            child: Text(value == null ? 'Set' : 'Change', style: TextStyle(color: _accent)),
          ),
          if (value != null) TextButton(onPressed: () { onClear(); setModalState(() {}); }, child: const Text('Clear', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  Widget _dateRow(String label, DateTime? value, ValueChanged<DateTime> onPicked, VoidCallback onClear) {
    final overdue = _isOverdue(value);
    final dueSoon = _isDueWithinDays(value, 30);
    Color? statusColor = overdue ? Colors.redAccent : (dueSoon ? Colors.orange : null);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, color: _accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value == null ? "Not set" : _fmtDate(value),
                  style: TextStyle(color: statusColor ?? Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _pickDate(current: value, onPicked: onPicked),
            child: Text(value == null ? "Set" : "Change", style: TextStyle(color: _accent, fontWeight: FontWeight.w600)),
          ),
          if (value != null)
            TextButton(
              onPressed: onClear,
              child: const Text("Clear", style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
        ],
      ),
    );
  }

}
