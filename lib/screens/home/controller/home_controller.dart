import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:marine_safe_app_fixed/models/ramp.dart';
import 'package:marine_safe_app_fixed/models/vessel.dart';
import 'package:marine_safe_app_fixed/data/ramp_data.dart';

import '../models/home_trip_state.dart';
import '../services/trip_prefs.dart';
import '../services/compliance_service.dart';
import '../services/people_on_board_service.dart';
import '../services/favourite_ramps_service.dart';
import '../services/home_notifications_service.dart';
import '../services/exact_alarm_permission_service.dart';

import '../../../services/fix_issue_router.dart';
import '../../../screens/reliability/reliability_check_screen.dart';

import '../widgets/compliance_disclaimer_dialog.dart';
import '../widgets/trip_manage_sheet.dart';

import '../../home_overdue_flow.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/expiry_notification_scheduler.dart';
import '../../../services/trip_cloud_service.dart';
import '../../../services/trip/trip_escalation_service.dart';
import '../../../services/trip_foreground_service.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/user_profile_service.dart';
import '../../../services/vessels_service.dart';

class HomeController extends ChangeNotifier with WidgetsBindingObserver {
  /// Notifier for shell UI (e.g. hide bottom nav when trip is active). Listen from MainShell.
  static final ValueNotifier<bool> tripActiveNotifier = ValueNotifier<bool>(false);

  final HomeTripState state = HomeTripState();

  final HomeNotificationsService _notifs = HomeNotificationsService();
  final HomeOverdueFlow _overdueFlow = HomeOverdueFlow();

  final FavouriteRampsService _favs = FavouriteRampsService();
  List<String> favouriteRampIds = <String>[];

  final TripCloudService _cloud = TripCloudService.instance;

  Timer? _uiTicker; // updates UI & overdue flow while app is open
  Timer? _cloudTicker; // writes cloud heartbeat

  bool _safetyDialogShownThisSession = false;
  static const String _kSafetyNoticeLastShownYmd = 'safety.notice.lastShownYmd';

  int _lastCloudWriteMs = 0;
  static const int _cloudMinIntervalMs = 8000;

  /// Ramps shown in ramp selector: local (by postcode) when available, else all.
  List<Ramp> _rampsForSelection = List<Ramp>.from(australianRamps);
  List<Ramp> get rampsForSelection => _rampsForSelection;

  /// True when the list is filtered by postcode (within 200 km).
  bool _showingLocalRamps = false;
  bool get showingLocalRamps => _showingLocalRamps;
  String? get rampListSubtitle => _showingLocalRamps ? 'Near your postcode (within 200 km)' : null;

  /// Current reliability issues (refreshed on app resume). Use for Fix button / banner.
  List<FixIssue> _reliabilityIssues = [];
  List<FixIssue> get reliabilityIssues => _reliabilityIssues;

  static const double _localRampRadiusMeters = 200 * 1000; // 200 km

  // ---------------------------
  // LIFECYCLE
  // ---------------------------

  Future<void> init(BuildContext context) async {
    WidgetsBinding.instance.addObserver(this);

    await _notifs.init();

    // Load model state (ramp, etc)
    await state.load();

    // ✅ Hard truth for trip/eta/ack comes from prefs (survives app close)
    await _rehydrateFromPrefs();

    favouriteRampIds = await _favs.getIds();

    // Build ramp list from postcode: local ramps when we have postcode + geocode
    await _updateRampsForSelection();
    notifyListeners();

    if (!context.mounted) return;

    // Ensure user has a name saved
    await UserProfileService.instance.ensureUserName(context);

    // Always resync schedules on startup
    await _syncSchedules();

    // Reschedule 14-day and 30-day expiry warnings (boat, trailer, safety equipment)
    await ExpiryNotificationScheduler.instance.scheduleAllExpiryNotifications();

    // If trip already active (e.g. app was killed), restart foreground service and GPS tracking
    if (state.tripActive && state.selectedRamp != null) {
      await TripPrefs.setRampName(state.selectedRamp!.name);
      // Restart background service and GPS tracking if trip is already active
      try {
        await startTripService();
      } catch (_) {
        // Service may already be running, ignore error
      }
    }

    // UI ticker: keep HomeScreen status ticking (countdown / overdue)
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _overdueTick(context);
      notifyListeners();
    });

    // Cloud heartbeat: less frequent
    _cloudTicker?.cancel();
    _cloudTicker = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _maybeCloudHeartbeat();
    });

    await _safeCloudUpsert();
    _reliabilityIssues = await FixIssueRouter.checkReliabilityIssues();
    notifyListeners();
  }

  void disposeController() {
    _uiTicker?.cancel();
    _uiTicker = null;

    _cloudTicker?.cancel();
    _cloudTicker = null;

    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void dispose() {
    disposeController();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ✅ Rehydrate again (prevents any “active=false eta=null” wipeouts)
      _rehydrateFromPrefs().then((_) => _syncSchedules());
      _safeCloudUpsert();
      // Re-check reliability issues after returning from Settings
      FixIssueRouter.checkReliabilityIssues().then((issues) {
        _reliabilityIssues = issues;
        notifyListeners();
      });
    }
  }

  // ---------------------------
  // PREFS REHYDRATE (CRITICAL)
  // ---------------------------

  Future<void> _rehydrateFromPrefs() async {
    final tripActive = await TripPrefs.getTripActive();
    final etaIso = await TripPrefs.getEtaIso();
    final ack = await TripPrefs.getOverdueAck();

    state.tripActive = tripActive;
    tripActiveNotifier.value = tripActive;
    state.overdueAcknowledged = ack;

    if (etaIso != null) {
      state.eta = DateTime.tryParse(etaIso);
    } else {
      state.eta = null;
    }

    // ignore: avoid_print
    print('REHYDRATE: active=${state.tripActive} eta=${state.eta} ack=${state.overdueAcknowledged}');
  }

  // ---------------------------
  // CLOUD SAFE WRAPPERS (offline-safe)
  // ---------------------------

  Future<void> _safeCloudUpsert() async {
    try {
      await _cloud.upsertFromState(state);
    } catch (e) {
      // ignore: avoid_print
      print('Cloud upsert failed (offline?): $e');
    }
  }

  Future<void> _safeCloudMarkEnded() async {
    try {
      await _cloud.markEnded();
    } catch (e) {
      // ignore: avoid_print
      print('Cloud markEnded failed (offline?): $e');
    }
  }

  // ---------------------------
  // LOCAL RAMPS (by postcode)
  // ---------------------------

  /// Last postcode we used to build the ramp list; when it changes we clear geocode cache.
  String? _lastPostcodeUsedForRamps;

  Future<void> _updateRampsForSelection() async {
    final currentPostcode = await UserProfileService.instance.getPostcode();
    if (currentPostcode != _lastPostcodeUsedForRamps) {
      _lastPostcodeUsedForRamps = currentPostcode;
      await UserProfileService.instance.clearPostcodeLatLonCache();
    }
    final latLon = await UserProfileService.instance.getPostcodeLatLon();
    if (latLon == null) {
      _rampsForSelection = List<Ramp>.from(australianRamps);
      _showingLocalRamps = false;
      return;
    }
    final withDistance = <(Ramp r, double meters)>[];
    for (final r in australianRamps) {
      final m = Geolocator.distanceBetween(
        latLon.lat,
        latLon.lon,
        r.lat,
        r.lon,
      );
      if (m <= _localRampRadiusMeters) withDistance.add((r, m));
    }
    withDistance.sort((a, b) => a.$2.compareTo(b.$2));
    if (withDistance.isEmpty) {
      _rampsForSelection = List<Ramp>.from(australianRamps);
      _showingLocalRamps = false;
    } else {
      _rampsForSelection = withDistance.map((e) => e.$1).toList();
      _showingLocalRamps = true;
    }
  }

  /// Call after user changes postcode (e.g. in Profile) so ramp list refreshes next time Home opens.
  Future<void> refreshRampsForSelection() async {
    await _updateRampsForSelection();
    notifyListeners();
  }

  // ---------------------------
  // FAVOURITES
  // ---------------------------

  List<Ramp> get favouriteRamps {
    final byId = {for (final r in australianRamps) r.id: r};
    final out = <Ramp>[];
    for (final id in favouriteRampIds) {
      final r = byId[id];
      if (r != null) out.add(r);
    }
    return out;
  }

  bool isFavouriteRamp(String rampId) => favouriteRampIds.contains(rampId);

  Future<void> toggleFavouriteRamp(Ramp ramp) async {
    favouriteRampIds = await _favs.toggle(ramp.id);
    notifyListeners();
    await _safeCloudUpsert();
  }

  // ---------------------------
  // SAFETY DISCLAIMER (daily)
  // ---------------------------

  Future<void> showSafetyDisclaimerIfNeeded(BuildContext context) async {
    if (_safetyDialogShownThisSession) return;

    final p = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final todayYmd = '$y-$m-$d';

    final lastShown = p.getString(_kSafetyNoticeLastShownYmd);
    if (lastShown == todayYmd) {
      _safetyDialogShownThisSession = true;
      return;
    }

    _safetyDialogShownThisSession = true;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          "Important Safety Notice",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Text(
            '''Marine Safe does NOT replace emergency services or marine communications.

• In an emergency call: 000
• Use VHF Marine Radio: Channel 16

This app is a trip planning and reminder tool only.

Always carry and use proper safety equipment and communication devices.
If you are in immediate danger, call 000 or use VHF Channel 16 immediately.''',
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("I UNDERSTAND"),
          ),
        ],
      ),
    );

    await p.setString(_kSafetyNoticeLastShownYmd, todayYmd);
  }

  // ---------------------------
  // OVERDUE DIALOG FLOW
  // ---------------------------

  Future<void> showOverdueDialogIfNeeded(BuildContext context) async {
    await _rehydrateFromPrefs(); // ✅ ensure truth
    if (!context.mounted) return;
    if (!state.tripActive || state.eta == null) return;
    if (!state.isOverdue) return;
    if (state.overdueAcknowledged) return;

    await _overdueFlow.show(
      context: context,
      onAcknowledge: () => acknowledgeOverdue(context),
    );
  }

  Future<void> _overdueTick(BuildContext context) async {
    // ✅ Don’t let app-open UI tick depend on in-memory only
    await _rehydrateFromPrefs();

    if (!state.tripActive || state.eta == null) return;
    if (state.overdueAcknowledged) return;

    final now = DateTime.now();
    // Overdue stage aligns with OS schedule: ETA + 5 minutes
    if (!now.isAfter(state.eta!.add(const Duration(minutes: 5)))) return;

    if (!state.overdueAlertFiredThisTrip) {
      state.overdueAlertFiredThisTrip = true;

      // ✅ App is open: show the in-app overdue flow, but do NOT emit extra system notifications.
      // Also cancel any legacy scheduled repeats from older versions.
      await TripPrefs.setOverdueNotifSent(true);
      await _notifs.cancelOverdueRepeats();

      await _safeCloudUpsert();

      if (!context.mounted) return;
      // Strong dedupe across restarts (only once we know we can actually present UI).
      final alreadyRecorded = await TripPrefs.getOverdueRecorded();
      if (alreadyRecorded) return;
      await TripPrefs.setOverdueRecorded(true);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        if (state.overdueAcknowledged) return;
        await showOverdueDialogIfNeeded(context);
      });
    }
  }

  Future<void> acknowledgeOverdue(BuildContext context) async {
    await TripEscalationService.instance.acknowledgeTrip();
    state.overdueAcknowledged = true;
    await TripPrefs.setOverdueAck(true); // Persist so _rehydrateFromPrefs doesn't overwrite
    // Ensure any legacy/local overdue schedules are cancelled too.
    try {
      await _notifs.cancelAll();
    } catch (_) {}
    notifyListeners();
    try {
      await _cloud.setAcknowledged();
    } catch (e) {
      print('Cloud setAcknowledged failed (offline?): $e');
    }
    await _safeCloudUpsert();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Overdue acknowledged ✅")),
    );
  }

  // ---------------------------
  // STATE CHANGES
  // ---------------------------

  Future<void> clearRamp() async {
    if (state.tripActive) return;
    state.selectedRamp = null;
    await TripPrefs.setRampId(null);
    await state.save();
    await _syncSchedules();
    notifyListeners();
    await _safeCloudUpsert();
  }

  Future<void> clearEta() async {
    if (state.tripActive) return;
    state.eta = null;
    await TripPrefs.setEtaIso(null);
    await state.save();
    await _syncSchedules();
    notifyListeners();
    await _safeCloudUpsert();
  }

  Future<void> setRamp(Ramp ramp) async {
    await state.setRamp(ramp);
    await TripPrefs.setRampId(ramp.id); // ✅
    await state.save();
    await _syncSchedules();
    notifyListeners();
    await _safeCloudUpsert();
  }

  /// Use GPS to find nearest ramp from [australianRamps] and set it as selected.
  /// Shows SnackBar on success or error (permission, location off, etc.).
  Future<void> selectNearestRampByLocation(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      scaffold.showSnackBar(
        const SnackBar(content: Text('Turn on device location to use “Use my location”.')),
      );
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!context.mounted) return;
      scaffold.showSnackBar(
        const SnackBar(content: Text('Location permission is required for “Use my location”.')),
      );
      return;
    }
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (e) {
      if (!context.mounted) return;
      scaffold.showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
      return;
    }
    if (australianRamps.isEmpty) {
      if (!context.mounted) return;
      scaffold.showSnackBar(const SnackBar(content: Text('No ramps in list.')));
      return;
    }
    Ramp? nearest = australianRamps.first;
    double minM = double.infinity;
    for (final r in australianRamps) {
      final m = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        r.lat,
        r.lon,
      );
      if (m < minM) {
        minM = m;
        nearest = r;
      }
    }
    if (nearest == null) {
      if (!context.mounted) return;
      scaffold.showSnackBar(const SnackBar(content: Text('No ramps in list.')));
      return;
    }
    await setRamp(nearest);
    if (!context.mounted) return;
    scaffold.showSnackBar(
      SnackBar(content: Text('Ramp set: ${nearest.name}')),
    );
  }

  Future<void> pickEta(BuildContext context) async {
    await state.pickEta(context);
    if (state.eta != null) {
      await TripPrefs.setEtaIso(state.eta!.toIso8601String()); // ✅
    }
    await TripPrefs.setOverdueNotifSent(false);
    await TripPrefs.setOverdueRecorded(false);
    await _notifs.cancelOverdueRepeats();
    await _syncSchedules();
    notifyListeners();
    await _safeCloudUpsert();
  }

  Future<void> extendEta(Duration delta) async {
    await state.extendEta(delta);
    if (state.eta != null) {
      await TripPrefs.setEtaIso(state.eta!.toIso8601String()); // ✅
    }
    await TripPrefs.setOverdueNotifSent(false);
    await TripPrefs.setOverdueRecorded(false);
    await _notifs.cancelOverdueRepeats();
    await _syncSchedules();
    notifyListeners();
    await _safeCloudUpsert();
  }

  Future<void> editPersonsOnBoard(BuildContext context) async {
    final v = await PeopleOnBoardService.ask(
      context: context,
      currentValue: state.personsOnBoard,
      requiredForStart: false,
    );
    if (v == null) return;

    state.personsOnBoard = v;
    await TripPrefs.setPersonsOnBoard(v);

    notifyListeners();
    await _safeCloudUpsert();

    // Refresh PFD/compliance alerts for the new count; show if any issues (use selected vessel when Pro)
    final isPro = await UserProfileService.instance.getIsPro();
    String? vesselId;
    String? boatRegoOverride;
    if (isPro) {
      vesselId = await VesselsService.instance.getSelectedVesselId();
      if (vesselId != null) {
        final vessels = await VesselsService.instance.getVessels();
        Vessel? selectedVessel;
        for (final e in vessels) {
          if (e.id == vesselId) { selectedVessel = e; break; }
        }
        boatRegoOverride = selectedVessel?.boatRego;
      }
    }
    final issues = await ComplianceService.check(personsOnBoard: state.personsOnBoard, vesselId: vesselId, boatRegoOverride: boatRegoOverride);
    if (issues.isNotEmpty && context.mounted) {
      await ComplianceDisclaimerDialog.showInformational(context, issues: issues);
    }
  }

  Future<void> startTrip(BuildContext context) async {
    if (state.selectedRamp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select a launch ramp before starting.")),
      );
      return;
    }

    final v = await PeopleOnBoardService.ask(
      context: context,
      currentValue: state.personsOnBoard,
      requiredForStart: true,
    );
    if (v == null || v <= 0) return;

    state.personsOnBoard = v;

    final isPro = await UserProfileService.instance.getIsPro();
    String? vesselId;
    String? boatRegoOverride;
    if (isPro) {
      vesselId = await VesselsService.instance.getSelectedVesselId();
      if (vesselId != null) {
        final vessels = await VesselsService.instance.getVessels();
        Vessel? selectedVessel;
        for (final e in vessels) {
          if (e.id == vesselId) { selectedVessel = e; break; }
        }
        boatRegoOverride = selectedVessel?.boatRego;
      }
    }
    final issues = await ComplianceService.check(personsOnBoard: state.personsOnBoard, vesselId: vesselId, boatRegoOverride: boatRegoOverride);
    if (!context.mounted) return;
    if (issues.isNotEmpty) {
      final proceed = await ComplianceDisclaimerDialog.show(context, issues: issues);
      if (!context.mounted) return;
      if (!proceed) return;
    }

    // Alert reliability: show once (after registration or first trip), not every trip
    if (!context.mounted) return;
    final alreadyAcknowledged = await TripPrefs.getAlertReliabilityAcknowledged();
    if (!alreadyAcknowledged) {
      final continued = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const ReliabilityCheckScreen(showContinueButton: true),
        ),
      );
      if (!context.mounted) return;
      if (continued != true) return;
      await TripPrefs.setAlertReliabilityAcknowledged(true);
    }
    if (!context.mounted) return;

    // So scheduled overdue alarms fire when app is closed
    try {
      await ExactAlarmPermissionService.ensureExactAlarmsEnabled(context);
    } catch (_) {}
    if (!context.mounted) return;

    state.tripActive = true;
    tripActiveNotifier.value = true;
    state.departAt = DateTime.now();

    state.overdueAcknowledged = false;
    state.overdueAlertFiredThisTrip = false;

    // ✅ Persist trip truth FIRST
    await TripPrefs.setTripActive(true);
    await TripPrefs.setOverdueAck(false);
    await TripPrefs.setOverdueNotifSent(false);
    await TripPrefs.setOverdueRecorded(false);
    if (state.selectedRamp != null) {
      await TripPrefs.setRampId(state.selectedRamp!.id);
      await TripPrefs.setRampName(state.selectedRamp!.name);
    }
    if (state.eta != null) {
      await TripPrefs.setEtaIso(state.eta!.toIso8601String());
    }

    await _notifs.cancelOverdueRepeats();

    await state.save();
    await _syncSchedules();

    // Start foreground service so overdue alerts fire when app is closed (Android)
    try {
      await startTripService();
    } catch (_) {}

    notifyListeners();

    _lastCloudWriteMs = 0;
    await _safeCloudUpsert();
    try {
      await _cloud.resetEscalationMarkers();
    } catch (e) {
      print('Cloud resetEscalationMarkers failed (offline?): $e');
    }
  }

  Future<void> endTrip() async {
    try {
      final rampName = state.selectedRamp?.name ?? await TripPrefs.getRampName();
      final startTime = state.departAt ?? await TripPrefs.getDepartAtIso().then((iso) => iso != null ? DateTime.tryParse(iso) : null);
      final stopTime = DateTime.now();
      final eta = state.eta;
      final name = (rampName != null && rampName.isNotEmpty) ? rampName : 'Unknown ramp';
      final entry = <String, dynamic>{
        'rampName': name,
        'startTime': startTime?.toIso8601String(),
        'stopTime': stopTime.toIso8601String(),
        if (eta != null) 'eta': eta.toIso8601String(),
      };
      final history = await LocalStorageService.loadTripHistory();
      history.insert(0, entry);
      await LocalStorageService.saveTripHistory(history);
    } catch (e, st) {
      debugPrint('Failed to save trip to history: $e\n$st');
    }

    try {
      await TripEscalationService.instance.cancelForTrip();
      await _notifs.cancelAll();
      try {
        await stopTripService();
      } catch (_) {}
    } catch (_) {
      // No-op on web / unsupported platforms; still clear trip below
    }

    await TripPrefs.setTripActive(false);
    await TripPrefs.setEtaIso(null);
    await TripPrefs.setRampName(null);
    await TripPrefs.setOverdueAck(false);
    await TripPrefs.setOverdueNotifSent(false);
    await TripPrefs.setOverdueRecorded(false);

    await state.endTripAndClearTripOnly();
    tripActiveNotifier.value = false;
    notifyListeners();

    await _safeCloudMarkEnded();
  }

  // ---------------------------
  // SCHEDULING
  // ---------------------------

  Future<void> _syncSchedules() async {
    // ✅ Always rehydrate before scheduling/canceling
    await _rehydrateFromPrefs();

    // ✅ Only cancel all when trip is NOT active.
    if (!state.tripActive) {
      await TripEscalationService.instance.cancelForTrip();
      await _notifs.cancelAll();
      // ignore: avoid_print
      print('SYNC: cancelled all (trip not active)');
      return;
    }

    // Trip is active but ETA missing -> do NOT cancel all.
    if (state.eta == null) {
      // ignore: avoid_print
      print('SYNC: trip active but ETA null (not cancelling all)');
      return;
    }

    // ignore: avoid_print
    print('SYNC: active=${state.tripActive} eta=${state.eta} ack=${state.overdueAcknowledged}');

    // OS-level escalation: DUE at ETA, OVERDUE at ETA+5, ESCALATING at ETA+10 then every 10 min (24×). Survives app kill/reboot.
    final tripId = FirebaseAuth.instance.currentUser?.uid ?? 'current';
    if (!state.overdueAcknowledged) {
      await TripEscalationService.instance.scheduleForTrip(
        eta: state.eta!,
        tripId: tripId,
      );
    } else {
      await TripEscalationService.instance.cancelForTrip();
    }

    // ignore: avoid_print
    print('SYNC: scheduled done');
  }

  Future<void> _maybeCloudHeartbeat() async {
    if (!state.tripActive) return;
    if (state.eta == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastCloudWriteMs < _cloudMinIntervalMs) return;

    _lastCloudWriteMs = nowMs;
    await _safeCloudUpsert();
  }

  // ---------------------------
  // MANAGE TRIP SHEET
  // ---------------------------

  void openManageTripSheet(BuildContext context) {
    if (!state.tripActive || state.eta == null) return;

    final rampName = state.selectedRamp?.name ?? "your ramp";
    final eta = state.eta!;

    final showAck = state.isOverdue && !state.overdueAcknowledged;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => TripManageSheet(
        rampName: rampName,
        eta: eta,
        personsOnBoard: state.personsOnBoard,
        onEditPeople: () async {
          Navigator.pop(context);
          await editPersonsOnBoard(context);
        },
        onExtend30m: () {
          Navigator.pop(context);
          extendEta(const Duration(minutes: 30));
        },
        onExtend1h: () {
          Navigator.pop(context);
          extendEta(const Duration(hours: 1));
        },
        showAcknowledge: showAck,
        onAcknowledgeOverdue: showAck
            ? () {
          Navigator.pop(context);
          acknowledgeOverdue(context);
        }
            : null,
        onEndTrip: () async {
          Navigator.pop(context);
          await endTrip();
        },
        onInviteCrew: state.personsOnBoard > 1
            ? () => TripCloudService.instance.getOrCreateJoinCode(state)
            : null,
      ),
    );
  }
}
