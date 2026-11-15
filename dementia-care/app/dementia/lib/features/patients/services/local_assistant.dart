import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'voice_assistant_service.dart';

/// Answers everyday questions on the phone itself: the time, the date, the
/// next reminders, a family phone number, the person's own name and address,
/// and a few kind words when the person feels low.
///
/// When nothing here matches, it returns null and the caller asks the AI
/// backend instead. This keeps the companion useful offline and when the AI
/// service is slow or unreachable.
class LocalAssistant {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static Future<VoiceAssistantResponse?> tryAnswer({
    required String query,
    required bool isHindi,
  }) async {
    final text = query.toLowerCase().trim();
    if (text.isEmpty) return null;

    if (_matches(
      text,
      ['hello', 'hi', 'hey', 'namaste'],
      ['नमस्ते', 'नमस्कार'],
    )) {
      final name = await _preferredName();
      return VoiceAssistantResponse(
        reply: isHindi
            ? 'नमस्ते${name == null ? '' : ' $name'}! मैं यहीं आपके साथ हूँ। आप कैसे हैं?'
            : 'Hello${name == null ? '' : ' $name'}! I am right here with you. How are you feeling?',
      );
    }

    if (_matches(
      text,
      ['time', 'clock', 'what time'],
      ['समय', 'बजे', 'टाइम'],
    )) {
      final now = DateFormat('h:mm a').format(DateTime.now());
      return VoiceAssistantResponse(
        reply: isHindi ? 'अभी $now है।' : 'It is $now right now.',
      );
    }

    if (_matches(
      text,
      ['date', 'today', 'which day'],
      ['तारीख', 'आज', 'दिन'],
    )) {
      final today = DateFormat('EEEE, d MMMM').format(DateTime.now());
      return VoiceAssistantResponse(
        reply: isHindi ? 'आज $today है।' : 'Today is $today.',
      );
    }

    if (_matches(text, ['call', 'phone', 'dial'], ['कॉल', 'फोन', 'बात'])) {
      return _callReply(_spokenName(text), isHindi);
    }

    if (_matches(
      text,
      ['reminder', 'reminders', 'medicine', 'medicines', 'tablet', 'pills'],
      ['दवा', 'दवाई', 'दवाइयाँ', 'रिमाइंडर', 'गोली'],
    )) {
      return VoiceAssistantResponse(reply: await _reminderReply(isHindi));
    }

    if (_matches(text, ['my name', 'who am i'], ['मेरा नाम', 'मैं कौन'])) {
      final name = await _field(['preferredName', 'name']);
      return VoiceAssistantResponse(
        reply: (name == null || name.isEmpty)
            ? (isHindi
                  ? 'आपका नाम अभी सहेजा नहीं गया है।'
                  : 'Your name is not saved yet.')
            : (isHindi ? 'आपका नाम $name है।' : 'Your name is $name.'),
      );
    }

    if (_matches(text, ['address', 'home', 'house'], ['पता', 'घर'])) {
      final address = await _field(['homeAddress']);
      return VoiceAssistantResponse(
        reply: (address == null || address.isEmpty)
            ? (isHindi
                  ? 'आपका पता अभी सहेजा नहीं गया है। आपके देखभालकर्ता इसे जोड़ सकते हैं।'
                  : 'Your address is not saved yet. Your caregiver can add it.')
            : (isHindi ? 'आपका पता $address है।' : 'Your address is $address.'),
      );
    }

    if (_matches(
      text,
      [
        'sad',
        'scared',
        'afraid',
        'lonely',
        'alone',
        'worried',
        'anxious',
        'upset',
      ],
      ['डर', 'उदास', 'अकेला', 'अकेली', 'चिंता', 'परेशान'],
    )) {
      return VoiceAssistantResponse(
        reply: isHindi
            ? 'मैं समझ सकता हूँ। आप अकेले नहीं हैं। धीरे-धीरे साँस लें। चाहें तो मैं आपके परिवार को कॉल कर सकता हूँ।'
            : 'I understand. You are not alone. Let us take a slow, gentle breath. I can call your family if you would like.',
      );
    }

    return null;
  }

  static Future<VoiceAssistantResponse?> _callReply(
    String spokenName,
    bool isHindi,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final patientRef = _firestore.collection('patients').doc(uid);
    final profile =
        (await patientRef.get()).data() ?? const <String, dynamic>{};
    final contacts = await patientRef.collection('contacts').get();

    String? phone;
    String? foundName;

    if (spokenName.isNotEmpty) {
      for (final doc in contacts.docs) {
        final data = doc.data();
        final contactName = (data['name'] ?? '').toString().trim();
        if (contactName.isEmpty) continue;
        final parts = contactName.toLowerCase().split(' ');
        final matches =
            spokenName.contains(contactName.toLowerCase()) ||
            parts.any((part) => part.length > 1 && spokenName.contains(part));
        if (matches) {
          phone = (data['phone'] ?? '').toString().trim();
          foundName = contactName;
          break;
        }
      }
    }

    phone ??= (profile['caregiverPhone'] as String?)?.trim();
    foundName ??= (profile['caregiverName'] as String?)?.trim();

    if (phone == null || phone.isEmpty) {
      return VoiceAssistantResponse(
        reply: isHindi
            ? 'मुझे वह नंबर नहीं मिला। आप परिवार के नंबर वाली स्क्रीन से कॉल कर सकते हैं।'
            : 'I could not find that number. You can call from the family contacts screen.',
      );
    }

    final cleanNumber = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return VoiceAssistantResponse(
      reply: isHindi
          ? 'ठीक है, ${foundName ?? 'आपके देखभालकर्ता'} को कॉल कर रहा हूँ।'
          : 'Of course. Calling ${foundName ?? 'your caregiver'} now.',
      action: 'call:$cleanNumber',
    );
  }

  static Future<String> _reminderReply(bool isHindi) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return isHindi
          ? 'रिमाइंडर देखने के लिए लॉगिन करें।'
          : 'Please sign in to see reminders.';
    }

    final snapshot = await _firestore
        .collection('patients')
        .doc(uid)
        .collection('reminders')
        .get();

    final reminders = snapshot.docs
        .map((doc) => doc.data())
        .where((data) => data['active'] != false)
        .toList();

    if (reminders.isEmpty) {
      return isHindi
          ? 'अभी कोई रिमाइंडर सेट नहीं है। आपके देखभालकर्ता इसे जोड़ सकते हैं।'
          : 'No reminders are set yet. Your caregiver can add them.';
    }

    final lines = reminders
        .take(3)
        .map((data) {
          final title = (data['title'] ?? '').toString().trim();
          final time = _friendlyTime((data['time'] ?? '').toString().trim());
          return '$time $title'.trim();
        })
        .where((line) => line.isNotEmpty)
        .toList();

    return isHindi
        ? 'आपके रिमाइंडर: ${lines.join(', ')}।'
        : 'Your reminders: ${lines.join(', ')}.';
  }

  static Future<String?> _preferredName() async {
    final name = await _field(['preferredName', 'name']);
    if (name == null || name.isEmpty) return null;
    return name.split(' ').first;
  }

  static Future<String?> _field(List<String> keys) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final data = (await _firestore.collection('patients').doc(uid).get())
        .data();
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String _spokenName(String text) {
    const noise = [
      'please',
      'can',
      'you',
      'me',
      'my',
      'to',
      'the',
      'call',
      'phone',
      'dial',
      'now',
      'mera',
      'meri',
      'ko',
      'se',
      'kar',
      'karo',
      'karein',
      'kijiye',
      'मेरा',
      'मेरी',
      'को',
      'कॉल',
      'करें',
      'करो',
      'कीजिए',
      'फोन',
    ];
    var cleaned = text;
    for (final word in noise) {
      cleaned = cleaned.replaceAll(RegExp('\\b${RegExp.escape(word)}\\b'), ' ');
    }
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _friendlyTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return raw;
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, hour, minute));
  }

  static bool _matches(
    String text,
    List<String> englishWords,
    List<String> hindiWords,
  ) {
    for (final word in englishWords) {
      if (RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(text)) return true;
    }
    for (final word in hindiWords) {
      if (text.contains(word)) return true;
    }
    return false;
  }
}
