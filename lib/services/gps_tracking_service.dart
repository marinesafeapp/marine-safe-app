import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/home/services/trip_prefs.dart';

/// GPS point model for local storage
class GPSPoint {
  final int? id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speed; // m/s
  final double? heading; // degrees
  final double? accuracy; // meters
  final bool synced; // whether this point has been synced to Firestore

  GPSPoint({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
    this.heading,
    this.accuracy,
    this.synced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'speed': speed,
      'heading': heading,
      'accuracy': accuracy,
      'synced': synced ? 1 : 0,
    };
  }

  factory GPSPoint.fromMap(Map<String, dynamic> map) {
    return GPSPoint(
      id: map['id'] as int?,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      speed: map['speed'] as double?,
      heading: map['heading'] as double?,
      accuracy: map['accuracy'] as double?,
      synced: (map['synced'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      if (accuracy != null) 'accuracy': accuracy,
    };
  }
}

/// Service for tracking GPS locations during active trips
/// Stores points locally in SQLite and syncs to Firestore when online
class GPSTrackingService {
  GPSTrackingService._();
  static final GPSTrackingService instance = GPSTrackingService._();

  Database? _database;
  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;
  Timer? _syncTimer;

  static const String _dbName = 'gps_tracking.db';
  static const String _tableName = 'gps_points';
  static const int _syncIntervalSeconds = 30; // Sync every 30 seconds when online
  static const int _distanceFilterMeters = 10; // Record point every 10 meters
  static const int _timeFilterSeconds = 30; // Or every 30 seconds, whichever comes first

  /// Initialize database
  Future<void> _initDatabase() async {
    if (_database != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            timestamp INTEGER NOT NULL,
            speed REAL,
            heading REAL,
            accuracy REAL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_timestamp ON $_tableName(timestamp)');
        await db.execute('CREATE INDEX idx_synced ON $_tableName(synced)');
      },
    );
  }

  /// Start tracking GPS locations (only when trip is active)
  Future<void> startTracking() async {
    if (_isTracking) return;

    // Check if trip is active
    final tripActive = await TripPrefs.getTripActive();
    if (!tripActive) return;

    // Check location permissions
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return; // Location services disabled
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return; // Permission denied
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return; // Permission denied forever
    }

    await _initDatabase();

    _isTracking = true;

    // Start listening to position updates
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
        timeLimit: Duration(seconds: _timeFilterSeconds),
      ),
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        // Log error but continue tracking
        print('GPS tracking error: $error');
      },
    );

    // Start periodic sync
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(seconds: _syncIntervalSeconds),
      (_) => _syncToFirestore(),
    );

    // Initial sync attempt
    _syncToFirestore();
  }

  /// Stop tracking GPS locations
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    _syncTimer?.cancel();
    _syncTimer = null;

    // Final sync attempt before stopping
    await _syncToFirestore();
  }

  /// Handle new position update
  Future<void> _onPositionUpdate(Position position) async {
    if (!_isTracking) return;

    // Double-check trip is still active
    final tripActive = await TripPrefs.getTripActive();
    if (!tripActive) {
      await stopTracking();
      return;
    }

    try {
      await _initDatabase();
      if (_database == null) return;

      final point = GPSPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp ?? DateTime.now(),
        speed: position.speed,
        heading: position.heading,
        accuracy: position.accuracy,
        synced: false,
      );

      // Save to local database
      await _database!.insert(_tableName, point.toMap());

      // Update lastLocation in trip document (for moderator view)
      await _updateLastLocation(point);
    } catch (e) {
      print('Error saving GPS point: $e');
    }
  }

  /// Update lastLocation field in trip document (trips/{tripId}.lastLocation)
  Future<void> _updateLastLocation(GPSPoint point) async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) return;

      final tripId = auth.currentUser!.uid; // tripId = user's UID
      if (tripId.isEmpty) return;

      final db = FirebaseFirestore.instance;
      // Store lastLocation as a field directly on the trip document: trips/{tripId}.lastLocation
      final tripRef = db.collection('trips').doc(tripId);

      final lastLocation = <String, dynamic>{
        'lat': point.latitude,
        'lng': point.longitude,
        'timestamp': Timestamp.fromDate(point.timestamp),
        'lastLocationUpdatedAt': Timestamp.fromDate(point.timestamp),
        if (point.speed != null) 'speed': point.speed,
        if (point.heading != null) 'heading': point.heading,
        if (point.accuracy != null) 'accuracy': point.accuracy,
      };

      await tripRef.set({
        'lastLocation': lastLocation,
      }, SetOptions(merge: true));
    } catch (e) {
      // Silently fail - offline or error, will retry later
      print('Error updating lastLocation: $e');
    }
  }

  /// Sync unsynced GPS points to Firestore
  Future<void> _syncToFirestore() async {
    if (_database == null) return;

    // Check if trip is still active
    final tripActive = await TripPrefs.getTripActive();
    if (!tripActive) {
      await stopTracking();
      return;
    }

    // Check internet connectivity (basic check)
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) return; // Not authenticated

      final db = FirebaseFirestore.instance;
      
      // Get user's trip document ID (tripId = user's UID)
      final tripId = auth.currentUser!.uid;
      if (tripId.isEmpty) return;

      // Get unsynced points
      final unsyncedPoints = await _database!.query(
        _tableName,
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'timestamp ASC',
        limit: 100, // Batch sync in chunks
      );

      if (unsyncedPoints.isEmpty) return;

      final batch = db.batch();
      final pointsToUpdate = <int>[];

      for (final row in unsyncedPoints) {
        final point = GPSPoint.fromMap(row);
        final pointId = point.id!;

        // Create document in Firestore subcollection: trips/{tripId}/gpsPoints/{pointId}
        final pointRef = db
            .collection('trips')
            .doc(tripId)
            .collection('gpsPoints')
            .doc(); // Auto-generated ID

        batch.set(pointRef, point.toFirestoreMap());
        pointsToUpdate.add(pointId);
      }

      // Commit batch write
      try {
        await batch.commit();

        // Mark points as synced
        for (final id in pointsToUpdate) {
          await _database!.update(
            _tableName,
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      } catch (e) {
        // Network error - points remain unsynced, will retry later
        print('Error syncing GPS points to Firestore: $e');
      }
    } catch (e) {
      // Offline or error - will retry on next sync cycle
      print('GPS sync error (likely offline): $e');
    }
  }

  /// Get the most recent GPS point (for notification payload / last known location).
  Future<GPSPoint?> getLastPoint() async {
    await _initDatabase();
    if (_database == null) return null;

    final maps = await _database!.query(
      _tableName,
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return GPSPoint.fromMap(maps.first);
  }

  /// Get all GPS points for current trip (for debugging/testing)
  Future<List<GPSPoint>> getAllPoints() async {
    await _initDatabase();
    if (_database == null) return [];

    final maps = await _database!.query(
      _tableName,
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => GPSPoint.fromMap(map)).toList();
  }

  /// Get unsynced point count
  Future<int> getUnsyncedCount() async {
    await _initDatabase();
    if (_database == null) return 0;

      final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE synced = 0',
    );

    return result.first['count'] as int? ?? 0;
  }

  /// Clear all GPS points (call when trip ends)
  Future<void> clearAllPoints() async {
    await _initDatabase();
    if (_database == null) return;

    await _database!.delete(_tableName);
  }

  /// Close database (call on app shutdown)
  Future<void> close() async {
    await stopTracking();
    await _database?.close();
    _database = null;
  }
}
