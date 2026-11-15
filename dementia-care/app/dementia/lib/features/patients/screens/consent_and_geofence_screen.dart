import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ConsentAndGeofenceScreen extends StatefulWidget {
  final bool isHindi;
  final String? patientId;

  const ConsentAndGeofenceScreen({
    super.key,
    this.isHindi = false,
    this.patientId,
  });

  @override
  State<ConsentAndGeofenceScreen> createState() =>
      _ConsentAndGeofenceScreenState();
}

class _ConsentAndGeofenceScreenState extends State<ConsentAndGeofenceScreen> {
  final MapController _mapController = MapController();

  bool _consentGiven = true;
  bool _isInsideSafeZone = true;
  bool _isChecking = false;
  bool _promptShowing = false;
  int _outsideReadingsCount = 0;
  double? _lastDistanceMeters;
  LatLng? _simulatedPos;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _patientSub;
  LatLng? _safeZoneCenter;
  double _safeZoneRadiusM = 200.0;
  LatLng? _livePatientPos;

  String get _pid =>
      widget.patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _listenToPatientGeofence();
  }

  @override
  void dispose() {
    _patientSub?.cancel();
    super.dispose();
  }

  LatLng? _parseLatLng(Map<String, dynamic>? map) {
    if (map == null || map['lat'] == null || map['lng'] == null) return null;
    return LatLng(
      (map['lat'] as num).toDouble(),
      (map['lng'] as num).toDouble(),
    );
  }

  /// Haversine formula to compute distance in meters between two LatLng coordinates.
  double _calculateDistanceMeters(LatLng a, LatLng b) {
    const double earthRadiusM = 6371000.0;
    final double dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final double dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    final double lat1 = a.latitude * math.pi / 180.0;
    final double lat2 = b.latitude * math.pi / 180.0;

    final double h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadiusM * c;
  }

  void _listenToPatientGeofence() {
    if (_pid.isEmpty) return;
    _patientSub = FirebaseFirestore.instance
        .collection('patients')
        .doc(_pid)
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;
      final data = snap.data() ?? {};

      final zoneMap = data['safeZone'] as Map<String, dynamic>?;
      final lastLocMap = data['lastLocation'] as Map<String, dynamic>?;
      final consent = data['locationSharingEnabled'] as bool? ?? true;

      final zoneCenter = _parseLatLng(zoneMap);
      final radius = (zoneMap?['radiusM'] as num?)?.toDouble() ?? 200.0;
      final livePos = _simulatedPos ?? _parseLatLng(lastLocMap);

      setState(() {
        _consentGiven = consent;
        _safeZoneCenter = zoneCenter;
        _safeZoneRadiusM = radius;
        _livePatientPos = livePos;
      });

      if (zoneCenter != null && livePos != null && _consentGiven) {
        _evaluateGeofence(livePos, zoneCenter, radius, fromStream: true);
      }
    });
  }

  void _evaluateGeofence(
    LatLng currentPos,
    LatLng zoneCenter,
    double radiusM, {
    bool fromStream = false,
  }) {
    final distance = _calculateDistanceMeters(currentPos, zoneCenter);
    final inside = distance <= radiusM;

    setState(() {
      _lastDistanceMeters = distance;
    });

    if (inside) {
      setState(() {
        _outsideReadingsCount = 0;
        _isInsideSafeZone = true;
      });
      return;
    }

    // Outside safe zone: require 2 consecutive readings to avoid GPS drift false alarms
    setState(() {
      _outsideReadingsCount += 1;
    });

    if (_outsideReadingsCount >= 2) {
      setState(() {
        _isInsideSafeZone = false;
      });
      if (!_promptShowing) {
        _showAreYouOkayPrompt();
      }
    } else if (!fromStream && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Reading 1/2 outside safe zone (${distance.toStringAsFixed(0)}m away). Checking again...',
              'सुरक्षित क्षेत्र से बाहर पहली रीडिंग (1/2) (${distance.toStringAsFixed(0)} मी दूर)। पुनः जाँच हो रही है...',
            ),
            style: const TextStyle(fontSize: 18),
          ),
          backgroundColor: Colors.amber.shade900,
        ),
      );
    }
  }

  Future<void> _toggleConsent(bool value) async {
    setState(() => _consentGiven = value);
    if (_pid.isEmpty) return;
    await FirebaseFirestore.instance.collection('patients').doc(_pid).set({
      'locationSharingEnabled': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _writeGeofenceAlertToCaregiver() async {
    if (_pid.isEmpty) return;
    final pos = _livePatientPos ?? _safeZoneCenter;
    await FirebaseFirestore.instance
        .collection('patients')
        .doc(_pid)
        .collection('alerts')
        .add({
      'type': 'geofence',
      'time': FieldValue.serverTimestamp(),
      'status': 'unread',
      'message': 'Patient stepped outside the designated Safe Zone.',
      'distanceMeters': _lastDistanceMeters?.round(),
      'radiusMeters': _safeZoneRadiusM.round(),
      if (pos != null)
        'location': {
          'lat': pos.latitude,
          'lng': pos.longitude,
        },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _runDemoGeofenceTest(bool simulateOutside) async {
    setState(() => _isChecking = true);
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _isChecking = false);

    // Fallback coordinates if safeZone hasn't been configured by caregiver yet
    final baseCenter = _safeZoneCenter ?? const LatLng(28.6139, 77.2090);

    if (!simulateOutside) {
      setState(() {
        _simulatedPos = baseCenter;
        _livePatientPos = baseCenter;
        _safeZoneCenter ??= baseCenter;
        _outsideReadingsCount = 0;
        _isInsideSafeZone = true;
        _lastDistanceMeters = 0;
      });
      _mapController.move(baseCenter, 16);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Inside Safe Zone (Home).', 'सुरक्षित क्षेत्र (घर) के अंदर हैं।'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal.shade700,
        ),
      );
      return;
    }

    // Offset ~350 meters north so it clearly crosses the default 200m safe zone
    final outsidePoint = LatLng(
      baseCenter.latitude + (_safeZoneRadiusM + 150) / 111320.0,
      baseCenter.longitude,
    );

    setState(() {
      _safeZoneCenter ??= baseCenter;
      _simulatedPos = outsidePoint;
      _livePatientPos = outsidePoint;
    });
    _mapController.move(outsidePoint, 15.5);

    _evaluateGeofence(outsidePoint, baseCenter, _safeZoneRadiusM);
  }

  Future<void> _showAreYouOkayPrompt() async {
    _promptShowing = true;
    final isOkay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E242B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _t('Are you okay?', 'क्या आप ठीक हैं?'),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.amberAccent,
          ),
        ),
        content: Text(
          _t(
            'You appear to be outside your safe zone. Tap "I am okay" or we will notify your caregiver.',
            'आप अपने सुरक्षित क्षेत्र से बाहर लग रहे हैं। "मैं ठीक हूँ" दबाएँ, अन्यथा हम आपके देखभालकर्ता को सूचित करेंगे।',
          ),
          style: const TextStyle(fontSize: 20, color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _t('Notify Caregiver', 'देखभालकर्ता को बताएं'),
              style: const TextStyle(fontSize: 18, color: Colors.amberAccent),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _t('I am okay', 'मैं ठीक हूँ'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    _promptShowing = false;

    if (!mounted) return;
    if (isOkay == true) {
      setState(() {
        _outsideReadingsCount = 0;
        _isInsideSafeZone = true;
        _simulatedPos = null;
      });
    } else {
      await _writeGeofenceAlertToCaregiver();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Caregiver alerted about Safe Zone exit.',
              'सुरक्षित क्षेत्र से बाहर जाने की सूचना देखभालकर्ता को भेज दी गई है।',
            ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.amber.shade900,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter =
        _livePatientPos ?? _safeZoneCenter ?? const LatLng(28.6139, 77.2090);

    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(_t('Safe Zone & Consent', 'सुरक्षित क्षेत्र और सहमति')),
        backgroundColor: Colors.teal.shade900,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Permanent Location Sharing Indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _consentGiven
                    ? Colors.teal.shade900.withOpacity(0.6)
                    : Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _consentGiven ? Colors.tealAccent : Colors.white38,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _consentGiven ? Icons.my_location : Icons.location_disabled,
                    color: _consentGiven ? Colors.tealAccent : Colors.white70,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _consentGiven
                          ? _t('Location Sharing is ON', 'लोकेशन शेयरिंग चालू है')
                          : _t(
                              'Location Sharing is PAUSED',
                              'लोकेशन शेयरिंग रुकी हुई है',
                            ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Safe Zone Status Banner (Calm teal/amber palette — no red)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _isInsideSafeZone
                    ? Colors.teal.shade900
                    : Colors.amber.shade900,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(
                    _isInsideSafeZone ? Icons.verified_user : Icons.explore_off,
                    size: 44,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isInsideSafeZone
                              ? _t(
                                  'Inside Safe Zone (Home)',
                                  'सुरक्षित क्षेत्र (घर) के अंदर',
                                )
                              : _t(
                                  'Outside Safe Zone • Caregiver Notified',
                                  'सुरक्षित क्षेत्र से बाहर • देखभालकर्ता को सूचित किया गया',
                                ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _safeZoneCenter == null
                              ? _t(
                                  'Using default 200m home boundary',
                                  'डिफ़ॉल्ट 200 मीटर घरेलू सीमा सक्रिय',
                                )
                              : _t(
                                  'Safe Radius: ${_safeZoneRadiusM.round()}m'
                                      '${_lastDistanceMeters != null ? ' • Distance: ${_lastDistanceMeters!.round()}m' : ''}',
                                  'सुरक्षित दायरा: ${_safeZoneRadiusM.round()} मी'
                                      '${_lastDistanceMeters != null ? ' • दूरी: ${_lastDistanceMeters!.round()} मी' : ''}',
                                ),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Live Safe Zone Map Preview (Synced with Caregiver LiveMapScreen)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.dementia_care',
                    ),
                    if (_safeZoneCenter != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _safeZoneCenter!,
                            radius: _safeZoneRadiusM,
                            useRadiusInMeter: true,
                            color: const Color(0x332E7D32),
                            borderColor: const Color(0xFF2E7D32),
                            borderStrokeWidth: 2.5,
                          ),
                        ],
                      ),
                    if (_livePatientPos != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _livePatientPos!,
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.person_pin_circle,
                              size: 48,
                              color: _isInsideSafeZone
                                  ? Colors.teal.shade800
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Consent Switch
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              title: Text(
                _t(
                  'Share Location with Caregiver',
                  'देखभालकर्ता के साथ लोकेशन साझा करें',
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                _t(
                  'Helps family support you if you walk out alone.',
                  'अकेले बाहर जाने पर परिवार को आपकी मदद करने में सहायक।',
                ),
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              value: _consentGiven,
              activeThumbColor: Colors.tealAccent,
              onChanged: _toggleConsent,
            ),
            const Divider(height: 24, color: Colors.white24),

            // Demo Geofence Triggers
            Text(
              _t('Demo Safe Zone Check:', 'डेमो सुरक्षित क्षेत्र जाँच:'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed:
                    _isChecking ? null : () => _runDemoGeofenceTest(false),
                child: Text(
                  _t(
                    'Simulate Inside Safe Zone',
                    'सुरक्षित क्षेत्र के अंदर दिखाएँ',
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed:
                    _isChecking ? null : () => _runDemoGeofenceTest(true),
                child: Text(
                  _t(
                    'Simulate Walking Out ($_outsideReadingsCount/2)',
                    'बाहर निकलने का डेमो ($_outsideReadingsCount/2)',
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
