import 'package:material_ui/material_ui.dart';

import '../content/story_library.dart';
import '../services/difficulty_engine.dart';
import '../services/reminder_notification_service.dart';
import '../services/session_logger.dart';

enum _StoryPhase { reading, question, finished }

/// Story Time: a short story is read aloud, then two or three gentle questions
/// follow. There is no timer and no failing score; a wrong answer simply invites
/// the person to look again together.
class StoryGameScreen extends StatefulWidget {
  final bool isHindi;

  const StoryGameScreen({super.key, this.isHindi = false});

  @override
  State<StoryGameScreen> createState() => _StoryGameScreenState();
}

class _StoryGameScreenState extends State<StoryGameScreen> {
  final DifficultyEngine _difficultyEngine = DifficultyEngine();
  final List<int> _answerTimesMs = [];

  late Story _story;
  _StoryPhase _phase = _StoryPhase.reading;
  int _questionIndex = 0;
  int? _chosenIndex;
  bool _showCorrectAnswer = false;
  bool _wrongThisQuestion = false;
  int _points = 0;
  int _questionsFirstTry = 0;
  int _storyRound = 0;
  bool _sessionLogged = false;
  DateTime _questionStartedAt = DateTime.now();

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  List<Story> get _availableStories {
    final level = _difficultyEngine.currentLevel;
    final forLevel = storyLibrary
        .where((story) => story.level <= level)
        .toList();
    return forLevel.isEmpty ? storyLibrary : forLevel;
  }

  @override
  void initState() {
    super.initState();
    ReminderNotificationService.initialize(isHindi: widget.isHindi);
    _story = _availableStories.first;
  }

  StoryQuestion get _question => _story.questions[_questionIndex];

  void _startQuestions() {
    setState(() {
      _phase = _StoryPhase.question;
      _questionIndex = 0;
      _chosenIndex = null;
      _showCorrectAnswer = false;
      _wrongThisQuestion = false;
      _questionsFirstTry = 0;
      _answerTimesMs.clear();
    });
    _questionStartedAt = DateTime.now();
  }

  void _readStoryAloud() {
    final text = _t(_story.textEn, _story.textHi);
    ReminderNotificationService.speakReminder(
      '${_t(_story.titleEn, _story.titleHi)}. $text',
    );
  }

  void _chooseOption(int index) {
    if (_chosenIndex != null) return;

    final isCorrect = index == _question.correctIndex;
    final elapsedMs = DateTime.now()
        .difference(_questionStartedAt)
        .inMilliseconds;

    if (isCorrect) {
      if (!_wrongThisQuestion) {
        _questionsFirstTry++;
        _answerTimesMs.add(elapsedMs);
      }
      setState(() {
        _chosenIndex = index;
        _showCorrectAnswer = true;
        _points += _wrongThisQuestion ? 5 : 10;
      });
      _difficultyEngine.adaptDifficulty(
        lastAnswerCorrect: true,
        currentStreak: 1,
        responseTimeMs: elapsedMs,
      );
      ReminderNotificationService.speakReminder(
        _t('Yes, that is right.', 'हाँ, यह सही है।'),
      );
      Future.delayed(const Duration(milliseconds: 1100), _nextQuestion);
      return;
    }

    setState(() {
      _wrongThisQuestion = true;
      _chosenIndex = index;
    });
    ReminderNotificationService.speakReminder(
      _t(
        'Not quite. Let us look again together.',
        'यह नहीं। आइए मिलकर फिर देखें।',
      ),
    );
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted || _showCorrectAnswer) return;
      setState(() => _chosenIndex = null);
    });
  }

  void _nextQuestion() {
    if (!mounted || !_showCorrectAnswer) return;
    if (_questionIndex + 1 >= _story.questions.length) {
      _finishStory();
      return;
    }
    setState(() {
      _questionIndex++;
      _chosenIndex = null;
      _showCorrectAnswer = false;
      _wrongThisQuestion = false;
    });
    _questionStartedAt = DateTime.now();
  }

  void _finishStory() {
    final totalQuestions = _story.questions.length;
    final accuracy = totalQuestions == 0
        ? 0.0
        : (_questionsFirstTry / totalQuestions).clamp(0.0, 1.0);
    final averageMs = _answerTimesMs.isEmpty
        ? 0
        : _answerTimesMs.reduce((a, b) => a + b) ~/ _answerTimesMs.length;

    setState(() {
      _phase = _StoryPhase.finished;
      _points += 15;
    });

    ReminderNotificationService.speakReminder(
      _t(
        'Thank you for reading with me. You did well.',
        'मेरे साथ पढ़ने के लिए धन्यवाद। आपने अच्छा किया।',
      ),
    );

    if (_sessionLogged) return;
    _sessionLogged = true;
    SessionLogger.logSession(
      game: 'story_time',
      level: _story.level,
      accuracy: accuracy,
      avgResponseMs: averageMs,
      language: widget.isHindi ? 'hi' : 'en',
    );
  }

  void _nextStory() {
    setState(() {
      _storyRound++;
      final stories = _availableStories;
      _story = stories[_storyRound % stories.length];
      _phase = _StoryPhase.reading;
      _questionIndex = 0;
      _chosenIndex = null;
      _showCorrectAnswer = false;
      _wrongThisQuestion = false;
      _questionsFirstTry = 0;
      _answerTimesMs.clear();
      _sessionLogged = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(_t('Story Time', 'कहानी का समय')),
        backgroundColor: Colors.deepPurple.shade900,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: switch (_phase) {
            _StoryPhase.reading => _buildReadingView(),
            _StoryPhase.question => _buildQuestionView(),
            _StoryPhase.finished => _buildFinishedView(),
          },
        ),
      ),
    );
  }

  Widget _buildReadingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade900,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _t(
              'Story ${_storyRound + 1} • Level ${_story.level}',
              'कहानी ${_storyRound + 1} • स्तर ${_story.level}',
            ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _t(_story.titleEn, _story.titleHi),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.amberAccent,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.deepPurple.shade200, width: 1.5),
            ),
            child: SingleChildScrollView(
              child: Text(
                _t(_story.textEn, _story.textHi),
                style: const TextStyle(
                  fontSize: 23,
                  height: 1.6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 66,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _readStoryAloud,
            icon: const Icon(Icons.volume_up, size: 32, color: Colors.white),
            label: Text(
              _t('Read to Me', 'मुझे सुनाएँ'),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 66,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _startQuestions,
            icon: const Icon(Icons.quiz, size: 32, color: Colors.white),
            label: Text(
              _t('Answer Questions', 'सवालों के जवाब दें'),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionView() {
    final total = _story.questions.length;
    final feedback = _showCorrectAnswer
        ? _t('Yes, that is right. Well done!', 'हाँ, यह सही है। बहुत बढ़िया!')
        : _wrongThisQuestion
        ? _t(
            'Let us read that part again. Take your time.',
            'आइए वह हिस्सा फिर पढ़ें। आराम से सोचें।',
          )
        : _t(
            'Choose the answer you remember.',
            'वह जवाब चुनें जो आपको याद है।',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _t(
                'Question ${_questionIndex + 1} of $total',
                'सवाल ${_questionIndex + 1} / $total',
              ),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Colors.amberAccent,
                  size: 28,
                ),
                const SizedBox(width: 6),
                Text(
                  _t('Points: $_points', 'अंक: $_points'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _t(_question.promptEn, _question.promptHi),
            style: const TextStyle(
              fontSize: 26,
              height: 1.4,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _showCorrectAnswer
                ? Colors.teal.shade900.withValues(alpha: 0.6)
                : Colors.deepPurple.shade900.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            feedback,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: _showCorrectAnswer ? Colors.tealAccent : Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < _question.options.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OptionButton(
                      label: _t(
                        _question.options[i].en,
                        _question.options[i].hi,
                      ),
                      isChosen: _chosenIndex == i,
                      isCorrect: i == _question.correctIndex,
                      revealCorrect: _showCorrectAnswer,
                      onTap: () => _chooseOption(i),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.auto_stories, size: 84, color: Colors.amberAccent),
            const SizedBox(height: 16),
            Text(
              _t('Story finished', 'कहानी पूरी हुई'),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.tealAccent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _t(
                'You answered $_questionsFirstTry of ${_story.questions.length} questions on the first try. Points: $_points.',
                'आपने पहली बार में ${_story.questions.length} में से $_questionsFirstTry सवालों के सही जवाब दिए। अंक: $_points।',
              ),
              style: const TextStyle(fontSize: 21, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 66,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _nextStory,
                icon: const Icon(
                  Icons.menu_book,
                  size: 30,
                  color: Colors.white,
                ),
                label: Text(
                  _t('Another Story', 'एक और कहानी'),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 66,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.tealAccent,
                  side: const BorderSide(color: Colors.tealAccent, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.home, size: 30),
                label: Text(
                  _t('Back to Home', 'घर वापस जाएँ'),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
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

class _OptionButton extends StatelessWidget {
  final String label;
  final bool isChosen;
  final bool isCorrect;
  final bool revealCorrect;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.isChosen,
    required this.isCorrect,
    required this.revealCorrect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color background = const Color(0xFF1E3A5F);
    Color border = Colors.lightBlueAccent;
    IconData? icon;

    if (revealCorrect && isCorrect) {
      background = Colors.teal.shade800;
      border = Colors.tealAccent;
      icon = Icons.check_circle;
    } else if (isChosen) {
      background = Colors.red.shade900;
      border = Colors.redAccent;
      icon = Icons.refresh;
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 2.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (icon != null) Icon(icon, color: Colors.white, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
