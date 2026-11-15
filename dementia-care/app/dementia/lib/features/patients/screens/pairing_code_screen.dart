import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PairingCodeScreen extends StatefulWidget {
  final bool isHindi;
  const PairingCodeScreen({super.key, this.isHindi = false});

  @override
  State<PairingCodeScreen> createState() => _PairingCodeScreenState();
}

class _PairingCodeScreenState extends State<PairingCodeScreen> {
  String _pairingCode = '--- ---';
  bool _isLoading = false;
  bool _linked = false;
  int _secondsRemaining = 600; // 10 minutes
  String _patientName = 'Patient';
  Timer? _countdownTimer;
  StreamSubscription<QuerySnapshot>? _requestSubscription;

  @override
  void initState() {
    super.initState();
    _loadPatientName();
    _generateCode();
    _startCountdown();
  }

  /// Uses the name saved on the profile so the caregiver sees a real name
  /// instead of a placeholder when the link is approved.
  Future<void> _loadPatientName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(uid)
          .get();
      final name = (doc.data()?['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty && mounted) {
        setState(() => _patientName = name);
      }
    } catch (_) {
      // Keep the calm fallback name; pairing still works.
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _requestSubscription?.cancel();
    super.dispose();
  }

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsRemaining = 600;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        _requestSubscription?.cancel();
        await _retireCurrentCode('expired'); // stop the code from working
      }
    });
  }

  String get _formattedTimer {
    final mins = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  /// Generates a 6-digit code locally and records it in Firestore so the
  /// caregiver side can validate it ('not-found', 'expired', 'used').
  Future<void> _generateCode() async {
    setState(() => _isLoading = true);

    final rand = Random.secure();
    final digits = List.generate(6, (_) => rand.nextInt(10)).join();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('pairing_codes')
            .doc(digits)
            .set({
              'uid': uid,
              'status': 'active',
              'createdAt': FieldValue.serverTimestamp(),
            });
      } catch (_) {
        // Offline: the code still shows, but the caregiver will get
        // 'not-found' — acceptable degradation for a pairing flow.
      }
    }

    if (!mounted) return;
    setState(() {
      _pairingCode = '${digits.substring(0, 3)}-${digits.substring(3)}';
      _isLoading = false;
      _linked = false;
    });
    _listenForPairingRequests(digits);
  }

  /// Watches for a caregiver request doc carrying this exact code and
  /// approves it while the timer is still running.
  void _listenForPairingRequests(String cleanCode) {
    _requestSubscription?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _requestSubscription = FirebaseFirestore.instance
        .collection('pairing_requests')
        .where('code', isEqualTo: cleanCode)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          (snapshot) async {
            if (_secondsRemaining <= 0) return;

            for (final doc in snapshot.docs) {
              final caregiverUid = doc.data()['caregiverUid'] as String;

              try {
                // ✅ 1. FORCE SAVE THE LINK.
                // The first merge keeps the patient document without caregivers
                // (allowed on create); the update then adds the caregiver.
                final patientRef = FirebaseFirestore.instance
                    .collection('patients')
                    .doc(uid);
                await patientRef.set({
                  'name': _patientName,
                }, SetOptions(merge: true));
                await patientRef.update({
                  'caregivers': FieldValue.arrayUnion([caregiverUid]),
                });

                // ✅ 2. Approve the request so the caregiver's app knows it succeeded
                await doc.reference.update({
                  'status': 'approved',
                  'pid': uid,
                  'patientName': _patientName,
                });

                // ✅ 3. Retire the code so it can't be reused
                await _retireCurrentCode('used');

                // ✅ 4. Clean up
                _requestSubscription?.cancel();
                _countdownTimer?.cancel();

                if (mounted) {
                  setState(() => _linked = true);
                }

                print(
                  '✅ [PATIENT] SUCCESS: Linked caregiver $caregiverUid to patient $uid',
                );
              } catch (e) {
                print('❌ [PATIENT] FAILED to save link: $e');
                // If saving fails, deny the request so the caregiver doesn't hang forever
                await doc.reference.update({'status': 'denied'});
              }
            }
          },
          onError: (e) {
            print('❌ [PATIENT] Query Error: $e');
          },
        );
  }

  Future<void> _retireCurrentCode(String status) async {
    final clean = _pairingCode.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 6) return;
    try {
      await FirebaseFirestore.instance
          .collection('pairing_codes')
          .doc(clean)
          .update({'status': status});
    } catch (_) {}
  }

  Future<void> _refreshCode() async {
    _requestSubscription?.cancel();
    await _retireCurrentCode('expired');
    _startCountdown();
    await _generateCode();
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _secondsRemaining == 0 && !_linked;

    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(_t('Link Caregiver', 'देखभालकर्ता जोड़ें')),
        backgroundColor: Colors.blueGrey.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_linked)
              Text(
                _t(
                  'Caregiver linked successfully!',
                  'देखभालकर्ता सफलतापूर्वक जुड़ गए!',
                ),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent,
                ),
                textAlign: TextAlign.center,
              )
            else ...[
              Text(
                _t(
                  'Ask your caregiver to enter this 6-digit code on their phone:',
                  'अपने देखभालकर्ता से यह 6-अंकों का कोड उनके फ़ोन पर डालने के लिए कहें:',
                ),
                style: const TextStyle(fontSize: 22, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isExpired ? Colors.amberAccent : Colors.tealAccent,
                    width: 2,
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.tealAccent,
                        ),
                      )
                    : Column(
                        children: [
                          Text(
                            isExpired
                                ? _t('EXPIRED', 'समय समाप्त')
                                : _pairingCode,
                            style: TextStyle(
                              fontSize: 46,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6,
                              color: isExpired
                                  ? Colors.amberAccent
                                  : Colors.tealAccent,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isExpired
                                ? _t(
                                    'Tap below for a new code',
                                    'नए कोड के लिए नीचे दबाएँ',
                                  )
                                : _t(
                                    'Expires in $_formattedTimer',
                                    '$_formattedTimer में समाप्त होगा',
                                  ),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 68,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _refreshCode,
                  icon: const Icon(
                    Icons.refresh,
                    size: 32,
                    color: Colors.white,
                  ),
                  label: Text(
                    _t('Generate New Code', 'नया कोड बनाएँ'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
