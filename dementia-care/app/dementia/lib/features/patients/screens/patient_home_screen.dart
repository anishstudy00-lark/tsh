import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/sos_service.dart';
import '../services/location_service.dart';
import 'game1_screen.dart';
import 'game2_screen.dart';
import 'story_game_screen.dart';
import 'pairing_code_screen.dart';
import 'consent_and_geofence_screen.dart';
import 'patient_reminders_screen.dart';
import 'voice_assistant_screen.dart';
import 'patient_contacts_screen.dart';
import 'patient_profile_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  bool _isSendingSos = false;
  bool _isHindi = false;
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    LocationService.initializeLocationAndBatteryExemption();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _t(String en, String hi) => _isHindi ? hi : en;

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E242B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _t('Logout?', 'लॉगआउट करें?'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Text(
          _t(
            'Are you sure you want to log out?',
            'क्या आप वाकई लॉगआउट करना चाहते हैं?',
          ),
          style: const TextStyle(fontSize: 18, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _t('Cancel', 'रद्द करें'),
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _t('Logout', 'लॉगआउट'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _confirmAndTriggerSos() async {
    HapticFeedback.heavyImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E242B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _t('Send Emergency SOS?', 'क्या आपातकालीन SOS भेजें?'),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Text(
          _t(
            'This will immediately alert your caregiver with your location.',
            'यह तुरंत आपके देखभालकर्ता को आपकी लोकेशन के साथ सूचित करेगा।',
          ),
          style: const TextStyle(fontSize: 20, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _t('Cancel', 'रद्द करें'),
              style: const TextStyle(fontSize: 20, color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _t('SEND SOS', 'SOS भेजें'),
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

    if (confirm != true) return;

    setState(() => _isSendingSos = true);
    final result = await SosService.triggerEmergencySos();

    if (!mounted) return;
    setState(() => _isSendingSos = false);

    final String message;
    if (result.alertQueued && result.smsOpened) {
      message = _t(
        'SOS sent. Your caregiver was alerted and a text message is open.',
        'SOS भेजा गया। देखभालकर्ता को सूचना दी गई और संदेश खुल रहा है।',
      );
    } else if (result.alertQueued) {
      message = _t(
        'SOS sent. Your caregiver has been alerted.',
        'SOS भेजा गया। आपके देखभालकर्ता को सूचना दे दी गई है।',
      );
    } else if (result.smsOpened) {
      message = _t(
        'Opened a text message to your caregiver. Please send it.',
        'देखभालकर्ता के लिए संदेश खुल गया है। कृपया उसे भेजें।',
      );
    } else {
      message = _t(
        'Could not send SOS. Please call your caregiver now.',
        'SOS नहीं भेजा जा सका। कृपया अभी देखभालकर्ता को कॉल करें।',
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: result.reachedSomeone
            ? Colors.teal.shade800
            : Colors.amber.shade900,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _openGameSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E242B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t('Choose an Activity', 'एक गतिविधि चुनें'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 68,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Game1Screen(isHindi: _isHindi),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.grid_view_rounded,
                  size: 32,
                  color: Colors.white,
                ),
                label: Text(
                  _t('Memory Pairs', 'चित्र जोड़ी मिलान'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 68,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Game2Screen(isHindi: _isHindi),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.shopping_basket,
                  size: 32,
                  color: Colors.white,
                ),
                label: Text(
                  _t('Shopping Basket', 'खरीदारी की टोकरी'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 68,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryGameScreen(isHindi: _isHindi),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.auto_stories,
                  size: 32,
                  color: Colors.white,
                ),
                label: Text(
                  _t('Story Time', 'कहानी का समय'),
                  style: const TextStyle(
                    fontSize: 22,
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

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(_now);
    final dateStr = DateFormat('EEEE, d MMM').format(_now);

    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar: Language toggle + Profile + Safe Zone + Link + Logout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.tealAccent,
                      side: const BorderSide(color: Colors.tealAccent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => setState(() => _isHindi = !_isHindi),
                    icon: const Icon(Icons.translate, size: 20),
                    label: Text(
                      _isHindi ? 'English' : 'हिन्दी',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: _t('My Profile', 'मेरी प्रोफ़ाइल'),
                        icon: const Icon(
                          Icons.person_pin,
                          size: 32,
                          color: Colors.amberAccent,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PatientProfileScreen(isHindi: _isHindi),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _t('Safe Zone', 'सुरक्षित क्षेत्र'),
                        icon: const Icon(
                          Icons.shield_outlined,
                          size: 32,
                          color: Colors.tealAccent,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ConsentAndGeofenceScreen(isHindi: _isHindi),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _t('Link Caregiver', 'देखभालकर्ता जोड़ें'),
                        icon: const Icon(
                          Icons.link,
                          size: 32,
                          color: Colors.tealAccent,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PairingCodeScreen(isHindi: _isHindi),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _t('Logout', 'लॉगआउट'),
                        icon: const Icon(
                          Icons.logout,
                          size: 32,
                          color: Colors.redAccent,
                        ),
                        onPressed: _handleLogout,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Large Clock & Date Header
              Center(
                child: Column(
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Next Reminder Banner
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientRemindersScreen(isHindi: _isHindi),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amberAccent.withOpacity(0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: Colors.amberAccent,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _t(
                            'Next: 01:30 PM • Lunch & Water',
                            'अगला: 01:30 PM • दोपहर का भोजन और पानी',
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4 Calm Huge Action Buttons
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _HugeTileButton(
                        title: _t('Play', 'खेलें'),
                        icon: Icons.extension,
                        color: Colors.teal.shade800,
                        onTap: _openGameSelector,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _HugeTileButton(
                        title: _t('Call Family', 'परिवार को कॉल'),
                        icon: Icons.call,
                        color: Colors.blue.shade800,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PatientContactsScreen(isHindi: _isHindi),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _HugeTileButton(
                        title: _t('Voice Help', 'आवाज़ सहायक'),
                        icon: Icons.mic,
                        color: Colors.indigo.shade700,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                VoiceAssistantScreen(isHindi: _isHindi),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _HugeTileButton(
                        title: _t('My Profile', 'मेरी प्रोफ़ाइल'),
                        icon: Icons.badge,
                        color: Colors.cyan.shade800,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PatientProfileScreen(isHindi: _isHindi),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5th Huge Button: SOS (ONLY red element in the UI)
              SizedBox(
                height: 76,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _isSendingSos ? null : _confirmAndTriggerSos,
                  icon: _isSendingSos
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.sos, size: 38, color: Colors.white),
                  label: Text(
                    _isSendingSos
                        ? _t('SENDING SOS...', 'SOS भेजा जा रहा है...')
                        : _t('EMERGENCY SOS', 'आपातकालीन SOS'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HugeTileButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HugeTileButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 52, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
