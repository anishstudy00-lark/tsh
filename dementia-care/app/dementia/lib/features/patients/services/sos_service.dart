import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants.dart';
import 'location_service.dart';

/// What actually happened when the patient pressed SOS, so the screen can tell
/// the truth with one short sentence.
class SosResult {
  /// The alert was written to `patients/{pid}/alerts`. Firestore queues it and
  /// sends it as soon as the phone has a connection again.
  final bool alertQueued;

  /// The phone opened the pre-filled SMS to the caregiver.
  final bool smsOpened;

  const SosResult({required this.alertQueued, required this.smsOpened});

  bool get reachedSomeone => alertQueued || smsOpened;
}

class SosService {
  /// Triggers the SOS flow:
  /// 1. Haptic confirmation.
  /// 2. Writes an alert doc {type, time, location, ackedBy, ackedAt}; the alert
  ///    function pushes it to every linked caregiver.
  /// 3. Never calls the AI.
  /// 4. Opens the pre-filled SMS when the alert cannot be queued or when no
  ///    caregiver is linked yet.
  static Future<SosResult> triggerEmergencySos() async {
    await HapticFeedback.heavyImpact();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final coordinates = await LocationService.getCurrentCoordinatesString();
    final location = _locationMap(coordinates);

    var alertQueued = false;
    var hasLinkedCaregiver = false;
    String? caregiverPhone;

    if (uid != null) {
      try {
        final patientDoc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(uid)
            .get();
        final data = patientDoc.data();
        caregiverPhone = (data?['caregiverPhone'] as String?)?.trim();
        final caregivers = data?['caregivers'];
        hasLinkedCaregiver = caregivers is List && caregivers.isNotEmpty;
      } catch (e) {
        if (kDebugMode) debugPrint('[SOS] Could not read patient profile: $e');
      }

      try {
        final alert = <String, dynamic>{
          'type': 'sos',
          'time': FieldValue.serverTimestamp(),
          'ackedBy': null,
          'ackedAt': null,
        };
        if (location != null) alert['location'] = location;

        // Offline persistence queues this write and sends it when online.
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(uid)
            .collection('alerts')
            .add(alert);
        alertQueued = true;
      } catch (e) {
        if (kDebugMode) debugPrint('[SOS] Could not write alert: $e');
      }
    }

    final phone = (caregiverPhone != null && caregiverPhone.isNotEmpty)
        ? caregiverPhone
        : AppConstants.defaultCaregiverPhone;

    // A queued alert is not instant help, so also open SMS whenever nobody is
    // linked yet or the write failed.
    var smsOpened = false;
    if (!alertQueued || !hasLinkedCaregiver) {
      smsOpened = await _sendSmsFallback(
        phoneNumber: phone,
        coordinates: coordinates,
      );
    }

    return SosResult(alertQueued: alertQueued, smsOpened: smsOpened);
  }

  static Map<String, double>? _locationMap(String? coordinates) {
    if (coordinates == null) return null;
    final parts = coordinates.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return {'lat': lat, 'lng': lng};
  }

  static Future<bool> _sendSmsFallback({
    required String phoneNumber,
    String? coordinates,
  }) async {
    final locationText = coordinates != null
        ? ' Location: https://maps.google.com/?q=$coordinates'
        : '';
    final message = Uri.encodeComponent(
      'EMERGENCY SOS: Your Care Companion user needs immediate help!$locationText',
    );

    final smsUri = Uri.parse('sms:$phoneNumber?body=$message');

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SOS] SMS fallback error: $e');
      }
      return false;
    }
  }
}
