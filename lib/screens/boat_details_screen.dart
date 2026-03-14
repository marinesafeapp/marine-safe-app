import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vessel.dart';
import '../services/boat_service.dart';
import '../services/expiry_notification_scheduler.dart';
import '../services/user_profile_service.dart';
import '../services/vessels_service.dart';
import 'pro_screen.dart';
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
  bool _formDirty = false;
  bool _isPro = false;
  List<Vessel> _vessels = [];
  List<String> _boatPhotoPaths = [];

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
    _boatNameCtrl.addListener(_markDirty);
    _regoCtrl.addListener(_markDirty);
    _trailerCtrl.addListener(_markDirty);
    _load();
  }

  void _markDirty() {
    if (mounted && _loaded) setState(() => _formDirty = true);
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
    _boatPhotoPaths = await BoatService.getBoatPhotoPaths();
    if (mounted) setState(() {
      _loaded = true;
      _formDirty = false;
    });
  }

  int get _maxBoatPhotos =>
      _isPro ? BoatService.maxPhotosPro : BoatService.maxPhotosFree;

  Future<void> _pickBoatPhoto() async {
    final max = _maxBoatPhotos;
    if (_boatPhotoPaths.length >= max) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isPro
                ? 'Maximum $max photos. Remove one to add another.'
                : 'One boat photo allowed. Upgrade to Pro for more.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null || !mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    final boatPhotosDir = Directory(p.join(dir.path, 'boat_photos'));
    if (!await boatPhotosDir.exists()) await boatPhotosDir.create(recursive: true);
    final name = 'boat_${DateTime.now().millisecondsSinceEpoch}${p.extension(xFile.path)}';
    final destPath = p.join(boatPhotosDir.path, name);
    await File(xFile.path).copy(destPath);
    final newList = List<String>.from(_boatPhotoPaths)..add(destPath);
    if (newList.length > max) newList.removeRange(max, newList.length);
    await BoatService.saveBoatPhotoPaths(newList);
    if (mounted) setState(() => _boatPhotoPaths = newList);
  }

  Future<void> _removeBoatPhoto(int index) async {
    final newList = List<String>.from(_boatPhotoPaths)..removeAt(index);
    await BoatService.saveBoatPhotoPaths(newList);
    if (mounted) setState(() => _boatPhotoPaths = newList);
  }

  Widget _boatPhotoSection() {
    const size = 120.0;
    const spacing = 12.0;
    return _card(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._boatPhotoPaths.asMap().entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: spacing),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(e.value),
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: size,
                            height: size,
                            color: Colors.white12,
                            child: const Icon(Icons.broken_image, color: Colors.white38, size: 40),
                          ),
                        ),
                      ),
                      Positioned(
                          top: -6,
                          right: -6,
                          child: Material(
                            color: Colors.black87,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: () => _removeBoatPhoto(e.key),
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              if (_boatPhotoPaths.length < _maxBoatPhotos)
                Padding(
                  padding: const EdgeInsets.only(right: spacing),
                  child: InkWell(
                    onTap: _pickBoatPhoto,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _accent.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, color: _accent, size: 36),
                          const SizedBox(height: 4),
                          Text(
                            _boatPhotoPaths.isEmpty ? 'Add boat photo' : 'Add another',
                            style: TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          if (_isPro && _boatPhotoPaths.isNotEmpty)
                            Text(
                              '${_boatPhotoPaths.length}/$_maxBoatPhotos',
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_boatPhotoPaths.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Image.asset('assets/images/boat.png', height: 48, width: 48, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.directions_boat_rounded, size: 48, color: Colors.white24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isPro ? 'Add up to $_maxBoatPhotos photos of your boat.' : 'Add a photo of your boat. Pro: add more.',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
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
      setState(() {
        _saving = false;
        _formDirty = false;
      });
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
          if (_formDirty)
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
                  if (!_isPro) ...[
                    _goProCard(),
                    const SizedBox(height: 24),
                  ],
                  _sectionLabel(_isPro ? "Default boat" : "Boat & trailer"),
                  _card(
                    children: [
                      _textField(_boatNameCtrl, "Boat name", Icons.directions_boat_rounded),
                      const SizedBox(height: 12),
                      _textField(_regoCtrl, "Boat rego", Icons.badge_rounded),
                      _dateRow("Boat rego expiry", _boatRegoExpiry, (d) => setState(() { _boatRegoExpiry = d; _formDirty = true; }), () => setState(() { _boatRegoExpiry = null; _formDirty = true; })),
                      const SizedBox(height: 12),
                      _textField(_trailerCtrl, "Trailer rego", Icons.badge_rounded),
                      _dateRow("Trailer rego expiry", _trailerRegoExpiry, (d) => setState(() { _trailerRegoExpiry = d; _formDirty = true; }), () => setState(() { _trailerRegoExpiry = null; _formDirty = true; })),
                    ],
                  ),
                  if (_formDirty) ...[
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 24),
                  ],
                  _sectionLabel("Boat photo(s)"),
                  _boatPhotoSection(),
                  const SizedBox(height: 24),
                  if (_isPro) ...[
                    _sectionLabel("Vessels"),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        _vessels.isEmpty
                            ? "Add your first boat or jet ski to get started."
                            : "Add boats or jet skis and switch between them for trips.",
                        style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.35),
                      ),
                    ),
                    ..._vessels.map((v) => _vesselTile(v)),
                    _addVesselCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _goProCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProScreen()),
        ).then((_) => _load()),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF2CB6FF), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      "Unlock more with Pro",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Multiple vessels, up to 10 boat photos, trip history & invite crew.",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProScreen()),
                  ).then((_) => _load()),
                  icon: const Icon(Icons.workspace_premium_rounded, size: 20),
                  label: const Text("Go Pro", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
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
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addOrEditVessel(vessel: v),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _accent.withValues(alpha: 0.35)),
                      ),
                      child: Icon(_iconForType(v.type), color: _accent, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            v.name.isEmpty ? 'Unnamed' : v.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _labelForType(v.type),
                                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (v.boatRego.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Rego: ${v.boatRego}',
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 22),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _vesselAction(
                      icon: Icons.health_and_safety_rounded,
                      label: 'Safety gear',
                      color: _accent,
                      onTap: () async {
                        await VesselsService.instance.setSelectedVesselId(v.id);
                        if (!mounted) return;
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyEquipmentScreen()));
                      },
                    ),
                    const SizedBox(width: 16),
                    _vesselAction(
                      icon: Icons.edit_rounded,
                      label: 'Edit',
                      color: Colors.white54,
                      onTap: () => _addOrEditVessel(vessel: v),
                    ),
                    const SizedBox(width: 16),
                    _vesselAction(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: Colors.red.shade300,
                      onTap: () => _confirmDeleteVessel(v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vesselAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addVesselCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _addOrEditVessel,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Color(0xFF2CB6FF), size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  "Add vessel",
                  style: TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
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
