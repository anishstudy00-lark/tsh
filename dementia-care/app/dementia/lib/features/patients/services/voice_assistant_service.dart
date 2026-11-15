import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceAssistantResponse {
  final String reply;
  final String action; // 'none' or 'call:<name>'

  const VoiceAssistantResponse({
    required this.reply,
    this.action = 'none',
  });
}

class VoiceAssistantService {
  static final FlutterTts _tts = FlutterTts();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> initialize({bool isHindi = false}) async {
    await setLanguage(isHindi: isHindi);
  }

  static Future<void> setLanguage({required bool isHindi}) async {
    await _tts.setLanguage(isHindi ? 'hi-IN' : 'en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
  }

  static Future<VoiceAssistantResponse> getAiCompanionResponse({
    required String userQuery,
    required String uid,
    bool isHindi = false,
  }) async {
    final fallback = VoiceAssistantResponse(
      reply: isHindi
          ? 'मैं यहीं आपके साथ हूँ। सब ठीक है, आप आराम करें।'
          : 'I am right here with you. Everything is alright, take a gentle breath.',
      action: 'none',
    );

    // The backend only accepts requests written as the signed-in patient.
    if (uid.isEmpty) return fallback;

    try {
      // 1. Write request to Firestore adhering strictly to security rules
      final requestId = await _sendRequestToAI(
        uid: uid,
        text: userQuery,
        language: isHindi ? 'hi' : 'en',
      );

      // 2. Wait for Python backend to process and add the 'reply' field
      final result = await _waitForAIResponse(requestId);
      
      final rawReply = result.reply.trim();
      String action = 'none';
      
      if (rawReply.toLowerCase().startsWith('call:')) {
        action = rawReply; 
      }

      return VoiceAssistantResponse(
        reply: rawReply,
        action: action,
      );

    } catch (e) {
      if (kDebugMode) debugPrint('[AI CHAT] Error or Timeout: $e');
      return fallback;
    }
  }

  /// Matches the exact keys allowed by Firestore rules: ['uid', 'text', 'language', 'history', 'createdAt']
  static Future<String> _sendRequestToAI({
    required String uid,
    required String text,
    required String language,
  }) async {
    final docRef = await _firestore.collection('assistantRequests').add({
      'uid': uid,
      'text': text,
      'language': language,
      'history': [], // Required by rule's hasOnly check
      'createdAt': FieldValue.serverTimestamp(), // Required by rule (instead of timestamp)
    });
    return docRef.id;
  }

  static Future<VoiceAssistantResponse> _waitForAIResponse(String requestId) async {
    final completer = Completer<VoiceAssistantResponse>();
    StreamSubscription<DocumentSnapshot>? sub;
    Timer? timer;

    sub = _firestore
        .collection('assistantRequests')
        .doc(requestId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      // The Python backend writes the answer as 'reply' (older builds used
      // 'response'); accept either so the assistant keeps working.
      final replyValue = data['reply'] ?? data['response'];
      if (replyValue != null) {
        if (!completer.isCompleted) {
          completer.complete(
            VoiceAssistantResponse(
              reply: replyValue.toString(),
            ),
          );
        }
      } else if (data.containsKey('error') && data['error'] != null) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(data['error'].toString()),
          );
        }
      }
    });

    timer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('AI response timed out'));
      }
    });

    try {
      final result = await completer.future;
      return result;
    } finally {
      timer.cancel();
      await sub.cancel();
    }
  }

  static Future<void> speak(String text) async {
    await _tts.stop();
    final hasHindiScript = RegExp(r'[\u0900-\u097F]').hasMatch(text);
    final isHindi = hasHindiScript || text.contains('मैं') || text.contains('नमस्ते') || text.contains('आप');
    
    await _tts.setLanguage(isHindi ? "hi-IN" : "en-US");
    await _tts.speak(text);
  }
}