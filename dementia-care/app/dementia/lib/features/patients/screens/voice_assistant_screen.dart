import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/local_assistant.dart';
import '../services/voice_assistant_service.dart';

class VoiceAssistantScreen extends StatefulWidget {
  final bool isHindi;
  const VoiceAssistantScreen({super.key, this.isHindi = false});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isLoading = false;
  String _lastWords = '';
  String _aiResponse = '';

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _lastWords = _t('Tap below and speak...', 'नीचे दबाएँ और बोलें...');
    _aiResponse = _t(
      'Hello! Ask me about the time, your reminders, or say "Call Aarav".',
      'नमस्ते! मुझसे समय, अपने रिमाइंडर के बारे में पूछें, या कहें "आरव को कॉल करें"।',
    );
    VoiceAssistantService.initialize(isHindi: widget.isHindi);
  }

  Future<void> _startListening() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        print('Speech recognition error: ${error.errorMsg}');
        setState(() => _isListening = false);
      },
    );
    
    if (!available) {
      setState(() {
        _aiResponse = _t('Speech recognition is not available.', 'वाक् पहचान उपलब्ध नहीं है।');
      });
      return;
    }

    setState(() => _isListening = true);
    
    _speech.listen(
      localeId: widget.isHindi ? 'hi_IN' : 'en_IN',
      // UPGRADE: dictation mode captures full, natural sentences better for elderly users
      listenMode: stt.ListenMode.dictation, 
      onResult: (SpeechRecognitionResult val) {
        setState(() => _lastWords = val.recognizedWords);
        
        // Only trigger AI when the user pauses and the engine marks it as final
        if (val.finalResult && val.recognizedWords.isNotEmpty) {
          _stopListening(); // Stop mic immediately to prevent it from hearing the AI's reply
          _handleUserQuery(val.recognizedWords);
        }
      },
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _handleUserQuery(String query) async {
    setState(() {
      _isListening = false;
      _isLoading = true;
    });

    final kindFallback = _t(
      'I am right here with you. Would you like me to open your family contacts?',
      'मैं यहीं आपके साथ हूँ। क्या आप चाहते हैं कि मैं आपके परिवार के नंबर खोलूँ?',
    );

    String replyText;
    try {
      // --- NEW AI TOUCH: Unified Firestore-driven flow ---
      // The service now handles writing, listening, timeout (15s), and fallbacks internally!
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // Everyday questions are answered on the phone itself, so the companion
      // keeps working offline or when the AI backend is not reachable.
      var response = await LocalAssistant.tryAnswer(
        query: query,
        isHindi: widget.isHindi,
      );

      if (response == null && uid != null && uid.isNotEmpty) {
        response = await VoiceAssistantService.getAiCompanionResponse(
          userQuery: query,
          uid: uid,
          isHindi: widget.isHindi,
        );
      }
      
      replyText = response?.reply ?? kindFallback;

      final action = response?.action ?? 'none';
      if (action.startsWith('call:')) {
        final number = action.substring('call:'.length).trim();
        final callUri = Uri(scheme: 'tel', path: number);
        if (number.isNotEmpty && await canLaunchUrl(callUri)) {
          await launchUrl(callUri);
        }
      }

    } catch (e) {
      // Ultimate fallback if something completely unexpected happens
      print("AI Response Error: $e");
      replyText = kindFallback;
    }

    if (!mounted) return;
    setState(() {
      _aiResponse = replyText;
      _isLoading = false;
    });

    await VoiceAssistantService.speak(replyText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(_t('Voice Assistant', 'आवाज़ सहायक')),
        backgroundColor: Colors.indigo.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade900,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.tealAccent, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.support_agent, size: 64, color: Colors.tealAccent),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.tealAccent)
                        : Text(
                            _aiResponse,
                            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_t('You said', 'आपने कहा')}: "$_lastWords"',
                style: const TextStyle(fontSize: 18, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 84,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isListening ? Colors.amber.shade900 : Colors.teal.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _isListening ? _stopListening : _startListening,
                icon: Icon(_isListening ? Icons.stop_circle : Icons.mic, size: 40, color: Colors.white),
                label: Text(
                  _isListening
                      ? _t('LISTENING... TAP TO STOP', 'सुन रहा हूँ... रोकने के लिए दबाएँ')
                      : _t('TAP TO SPEAK', 'बोलने के लिए दबाएँ'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}