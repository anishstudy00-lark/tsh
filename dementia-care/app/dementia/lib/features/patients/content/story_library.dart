/// Bilingual stories for the Story Time game.
///
/// Each story is short, warm and familiar, with two or three gentle questions.
/// Sentences stay simple, and nothing here makes a medical claim.
class StoryOption {
  final String en;
  final String hi;

  const StoryOption(this.en, this.hi);
}

class StoryQuestion {
  final String promptEn;
  final String promptHi;
  final List<StoryOption> options;
  final int correctIndex;

  const StoryQuestion({
    required this.promptEn,
    required this.promptHi,
    required this.options,
    required this.correctIndex,
  });
}

class Story {
  final String id;
  final int level;
  final String titleEn;
  final String titleHi;
  final String textEn;
  final String textHi;
  final List<StoryQuestion> questions;

  const Story({
    required this.id,
    required this.level,
    required this.titleEn,
    required this.titleHi,
    required this.textEn,
    required this.textHi,
    required this.questions,
  });
}

const List<Story> storyLibrary = [
  Story(
    id: 'morning_tea',
    level: 1,
    titleEn: 'The Morning Tea',
    titleHi: 'सुबह की चाय',
    textEn:
        'Ramesh wakes up at seven every morning. He makes two cups of tea and '
        'sits with his wife Kamla near the window. After tea, they walk slowly '
        'to the park and feed the pigeons.',
    textHi:
        'रमेश हर सुबह सात बजे उठते हैं। वे दो कप चाय बनाते हैं और अपनी पत्नी कमला के '
        'साथ खिड़की के पास बैठते हैं। चाय के बाद वे धीरे-धीरे पार्क तक टहलते हैं और '
        'कबूतरों को दाना खिलाते हैं।',
    questions: [
      StoryQuestion(
        promptEn: 'What does Ramesh drink in the morning?',
        promptHi: 'रमेश सुबह क्या पीते हैं?',
        correctIndex: 0,
        options: [
          StoryOption('Tea', 'चाय'),
          StoryOption('Milk', 'दूध'),
          StoryOption('Juice', 'जूस'),
        ],
      ),
      StoryQuestion(
        promptEn: 'Who sits with Ramesh near the window?',
        promptHi: 'खिड़की के पास रमेश के साथ कौन बैठता है?',
        correctIndex: 1,
        options: [
          StoryOption('His son', 'उनका बेटा'),
          StoryOption('His wife Kamla', 'उनकी पत्नी कमला'),
          StoryOption('His neighbour', 'उनका पड़ोसी'),
        ],
      ),
      StoryQuestion(
        promptEn: 'What do they feed in the park?',
        promptHi: 'वे पार्क में किसे दाना खिलाते हैं?',
        correctIndex: 2,
        options: [
          StoryOption('Cats', 'बिल्लियाँ'),
          StoryOption('Fish', 'मछलियाँ'),
          StoryOption('Pigeons', 'कबूतर'),
        ],
      ),
    ],
  ),
  Story(
    id: 'marigold_garden',
    level: 1,
    titleEn: 'The Marigold Garden',
    titleHi: 'गेंदे का बगीचा',
    textEn:
        'Savitri waters her marigolds every evening. Her granddaughter Nisha '
        'brings a small packet of seeds in March. By October the flowers are '
        'tall and bright, and they make garlands for the festival.',
    textHi:
        'सवित्री हर शाम अपने गेंदे के फूलों को पानी देती हैं। उनकी पोती निशा मार्च में '
        'बीजों का एक छोटा पैकेट लाती है। अक्टूबर तक फूल ऊँचे और चमकीले हो जाते हैं, '
        'और वे त्योहार के लिए माला बनाती हैं।',
    questions: [
      StoryQuestion(
        promptEn: 'Which flowers grow in Savitri garden?',
        promptHi: 'सवित्री के बगीचे में कौन से फूल उगते हैं?',
        correctIndex: 1,
        options: [
          StoryOption('Roses', 'गुलाब'),
          StoryOption('Marigolds', 'गेंदे के फूल'),
          StoryOption('Lotuses', 'कमल'),
        ],
      ),
      StoryQuestion(
        promptEn: 'Who brings the seeds?',
        promptHi: 'बीज कौन लाती है?',
        correctIndex: 2,
        options: [
          StoryOption('The doctor', 'डॉक्टर'),
          StoryOption('A neighbour', 'एक पड़ोसी'),
          StoryOption('Her granddaughter Nisha', 'उनकी पोती निशा'),
        ],
      ),
      StoryQuestion(
        promptEn: 'What do they make with the flowers?',
        promptHi: 'फूलों से वे क्या बनाती हैं?',
        correctIndex: 0,
        options: [
          StoryOption('Garlands', 'माला'),
          StoryOption('Baskets', 'टोकरी'),
          StoryOption('Bread', 'रोटी'),
        ],
      ),
    ],
  ),
  Story(
    id: 'sunday_visit',
    level: 2,
    titleEn: 'The Sunday Visit',
    titleHi: 'रविवार की मुलाकात',
    textEn:
        'Every Sunday, Meera visits her father with her son Aarav. They cook '
        'khichdi together and eat on the floor, the way they always did. After '
        'lunch they open the old photo album and then call Meera cousin in Pune.',
    textHi:
        'हर रविवार मीरा अपने बेटे आरव के साथ अपने पिता के घर आती है। वे मिलकर खिचड़ी '
        'बनाते हैं और ज़मीन पर बैठकर खाते हैं, जैसे हमेशा करते थे। खाने के बाद वे पुरानी '
        'फोटो एल्बम खोलते हैं और फिर मीरा की पुणे वाली बहन को फोन करते हैं।',
    questions: [
      StoryQuestion(
        promptEn: 'Who comes to visit on Sunday?',
        promptHi: 'रविवार को कौन मिलने आता है?',
        correctIndex: 0,
        options: [
          StoryOption('Meera and Aarav', 'मीरा और आरव'),
          StoryOption('The doctor', 'डॉक्टर'),
          StoryOption('The postman', 'डाकिया'),
        ],
      ),
      StoryQuestion(
        promptEn: 'What do they cook together?',
        promptHi: 'वे मिलकर क्या पकाते हैं?',
        correctIndex: 2,
        options: [
          StoryOption('Pasta', 'पास्ता'),
          StoryOption('Soup', 'सूप'),
          StoryOption('Khichdi', 'खिचड़ी'),
        ],
      ),
      StoryQuestion(
        promptEn: 'What do they look at after lunch?',
        promptHi: 'खाने के बाद वे क्या देखते हैं?',
        correctIndex: 1,
        options: [
          StoryOption('A newspaper', 'अख़बार'),
          StoryOption('An old photo album', 'पुरानी फोटो एलबम'),
          StoryOption('A map', 'नक्शा'),
        ],
      ),
    ],
  ),
  Story(
    id: 'evening_bus',
    level: 2,
    titleEn: 'The Evening Bus',
    titleHi: 'शाम की बस',
    textEn:
        'Mohan takes the number twelve bus to the market every Thursday. He buys '
        'fresh vegetables and a little fruit for the week. The greengrocer knows '
        'him well and helps carry the bag. Mohan is always home before dark.',
    textHi:
        'मोहन हर गुरुवार को बारह नंबर की बस से बाज़ार जाते हैं। वे हफ़्ते भर के लिए ताज़ी '
        'सब्ज़ियाँ और थोड़े फल खरीदते हैं। सब्ज़ी वाला उन्हें अच्छी तरह जानता है और थैला '
        'उठाने में मदद करता है। मोहन हमेशा अंधेरा होने से पहले घर लौट आते हैं।',
    questions: [
      StoryQuestion(
        promptEn: 'Which bus does Mohan take?',
        promptHi: 'मोहन कौन सी बस लेते हैं?',
        correctIndex: 1,
        options: [
          StoryOption('Number seven', 'सात नंबर'),
          StoryOption('Number twelve', 'बारह नंबर'),
          StoryOption('Number twenty one', 'इक्कीस नंबर'),
        ],
      ),
      StoryQuestion(
        promptEn: 'Who helps carry his bag?',
        promptHi: 'उनका थैला कौन उठाने में मदद करता है?',
        correctIndex: 2,
        options: [
          StoryOption('The bus driver', 'बस चालक'),
          StoryOption('A neighbour', 'एक पड़ोसी'),
          StoryOption('The greengrocer', 'सब्ज़ी वाला'),
        ],
      ),
      StoryQuestion(
        promptEn: 'When does Mohan reach home?',
        promptHi: 'मोहन घर कब पहुँचते हैं?',
        correctIndex: 0,
        options: [
          StoryOption('Before dark', 'अंधेरा होने से पहले'),
          StoryOption('Late at night', 'देर रात में'),
          StoryOption('At midnight', 'आधी रात को'),
        ],
      ),
    ],
  ),
  Story(
    id: 'rainy_afternoon',
    level: 2,
    titleEn: 'The Rainy Afternoon',
    titleHi: 'बारिश की दोपहर',
    textEn:
        'Rain comes suddenly on a hot afternoon. Asha makes pakoras while her '
        'grandson Kabir sets up the carrom board. They sit on the veranda and '
        'watch the water run down the street. The power goes off, so they light '
        'an old lamp and tell stories.',
    textHi:
        'गर्म दोपहर में अचानक बारिश आ जाती है। आशा पकौड़े बनाती हैं और उनका पोता कबीर '
        'कैरम बोर्ड लगाता है। वे बरामदे में बैठकर सड़क पर बहता पानी देखते हैं। बिजली चली '
        'जाती है, इसलिए वे पुराना दीपक जलाते हैं और कहानियाँ सुनाते हैं।',
    questions: [
      StoryQuestion(
        promptEn: 'What does Asha make?',
        promptHi: 'आशा क्या बनाती हैं?',
        correctIndex: 2,
        options: [
          StoryOption('Tea', 'चाय'),
          StoryOption('Sweets', 'मिठाई'),
          StoryOption('Pakoras', 'पकौड़े'),
        ],
      ),
      StoryQuestion(
        promptEn: 'Which game does Kabir set up?',
        promptHi: 'कबीर कौन सा खेल लगाता है?',
        correctIndex: 0,
        options: [
          StoryOption('Carrom', 'कैरम'),
          StoryOption('Cricket', 'क्रिकेट'),
          StoryOption('Ludo', 'लूडो'),
        ],
      ),
      StoryQuestion(
        promptEn: 'What do they light when the power goes off?',
        promptHi: 'बिजली जाने पर वे क्या जलाते हैं?',
        correctIndex: 1,
        options: [
          StoryOption('A candle', 'मोमबत्ती'),
          StoryOption('An old lamp', 'पुराना दीपक'),
          StoryOption('A bonfire', 'अलाव'),
        ],
      ),
    ],
  ),
];
