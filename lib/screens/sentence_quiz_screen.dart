import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jlpt_vocab_app_n1/l10n/generated/app_localizations.dart';
import '../db/database_helper.dart';
import '../models/word.dart';
import '../services/translation_service.dart';
import '../services/ad_service.dart';

/// 예문 빈칸 퀴즈 화면
/// N1 전용 실전형 학습 기능 - 예문에서 단어를 빈칸으로 만들어 문맥 파악력 테스트
class SentenceQuizScreen extends StatefulWidget {
  final String? level;

  const SentenceQuizScreen({super.key, this.level});

  @override
  State<SentenceQuizScreen> createState() => _SentenceQuizScreenState();
}

class _SentenceQuizScreenState extends State<SentenceQuizScreen> {
  List<Word> _words = [];
  List<Word> _quizWords = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _score = 0;
  final int _totalQuestions = 10;
  List<String> _options = [];
  String? _selectedOption;
  bool _answered = false;
  String _sentenceWithBlank = '';
  Map<int, String> _translatedDefinitions = {};

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final jsonWords = await DatabaseHelper.instance.getWordsWithTranslations();

    // 예문이 있는 단어만 필터링
    List<Word> words =
        jsonWords.where((w) {
          final hasExample = w.example.isNotEmpty && w.example.length > 10;
          final wordInExample =
              w.example.contains(w.word) ||
              (w.kanji != null && w.example.contains(w.kanji!)) ||
              (w.hiragana != null && w.example.contains(w.hiragana!));
          return hasExample && wordInExample;
        }).toList();

    if (widget.level != null) {
      words = words.where((w) => w.level == widget.level).toList();
    }

    words.shuffle();
    final quizWords = words.take(_totalQuestions).toList();

    // 번역 로드
    final translationService = TranslationService.instance;
    await translationService.init();
    final langCode = translationService.currentLanguage;

    if (translationService.needsTranslation) {
      for (var word in words) {
        final embeddedTranslation = word.getEmbeddedTranslation(
          langCode,
          'definition',
        );
        if (embeddedTranslation != null && embeddedTranslation.isNotEmpty) {
          _translatedDefinitions[word.id] = embeddedTranslation;
        }
      }
    }

    if (mounted) {
      setState(() {
        _words = words;
        _quizWords = quizWords;
        _isLoading = false;
        if (_quizWords.isNotEmpty) {
          _generateQuestion();
        }
      });
    }
  }

  /// 예문에서 단어를 빈칸으로 변환
  String _createBlankSentence(Word word) {
    String sentence = word.example;

    // 단어를 빈칸으로 치환 (우선순위: 한자 > 히라가나 > word)
    if (word.kanji != null && sentence.contains(word.kanji!)) {
      sentence = sentence.replaceFirst(word.kanji!, '（　　　）');
    } else if (word.hiragana != null && sentence.contains(word.hiragana!)) {
      sentence = sentence.replaceFirst(word.hiragana!, '（　　　）');
    } else if (sentence.contains(word.word)) {
      sentence = sentence.replaceFirst(word.word, '（　　　）');
    }

    return sentence;
  }

  void _generateQuestion() {
    if (_quizWords.isEmpty || _currentIndex >= _quizWords.length) return;

    final currentWord = _quizWords[_currentIndex];
    _sentenceWithBlank = _createBlankSentence(currentWord);

    // 정답 (표시용 단어)
    final correctAnswer =
        currentWord.kanji ?? currentWord.hiragana ?? currentWord.word;

    // 오답 생성 - 비슷한 품사의 단어들 중에서 선택
    final wrongAnswers = <String>[];
    final usedWords = <String>{correctAnswer};
    final random = Random();

    // 같은 품사 단어들 우선
    final samePosWords =
        _words
            .where(
              (w) =>
                  w.partOfSpeech == currentWord.partOfSpeech &&
                  w.id != currentWord.id,
            )
            .toList();

    while (wrongAnswers.length < 3) {
      Word? wrongWord;

      if (samePosWords.isNotEmpty && wrongAnswers.length < 2) {
        // 같은 품사에서 선택
        wrongWord = samePosWords[random.nextInt(samePosWords.length)];
      } else {
        // 전체에서 랜덤 선택
        wrongWord = _words[random.nextInt(_words.length)];
      }

      final wrongAnswer =
          wrongWord.kanji ?? wrongWord.hiragana ?? wrongWord.word;
      if (!usedWords.contains(wrongAnswer)) {
        usedWords.add(wrongAnswer);
        wrongAnswers.add(wrongAnswer);
      }
    }

    _options = [correctAnswer, ...wrongAnswers]..shuffle();
  }

  void _checkAnswer(String selectedOption) {
    if (_answered) return;

    final currentWord = _quizWords[_currentIndex];
    final correctAnswer =
        currentWord.kanji ?? currentWord.hiragana ?? currentWord.word;

    setState(() {
      _answered = true;
      _selectedOption = selectedOption;
      if (selectedOption == correctAnswer) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _quizWords.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOption = null;
        _generateQuestion();
      });
    } else {
      _showResultDialog();
    }
  }

  void _showResultDialog() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final percentage = (_score / _quizWords.length * 100).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.quizComplete),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  percentage >= 80
                      ? Icons.emoji_events
                      : percentage >= 60
                      ? Icons.thumb_up
                      : Icons.refresh,
                  size: 60,
                  color:
                      percentage >= 80
                          ? Colors.amber
                          : percentage >= 60
                          ? Colors.green
                          : Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  '$_score / ${_quizWords.length}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$percentage%',
                  style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  _getResultMessage(percentage),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text(l10n.close),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _restartQuiz();
                },
                child: Text(l10n.tryAgain),
              ),
            ],
          ),
    );
  }

  String _getResultMessage(int percentage) {
    final l10n = AppLocalizations.of(context)!;
    if (percentage >= 90) return l10n.excellentResult;
    if (percentage >= 80) return l10n.greatResult;
    if (percentage >= 60) return l10n.goodResult;
    return l10n.keepPracticing;
  }

  void _restartQuiz() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _answered = false;
      _selectedOption = null;
      _quizWords.shuffle();
      _quizWords = _quizWords.take(_totalQuestions).toList();
      _generateQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.sentenceQuiz)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_quizWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.sentenceQuiz)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sentiment_dissatisfied,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noExamplesAvailable,
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentWord = _quizWords[_currentIndex];
    final correctAnswer =
        currentWord.kanji ?? currentWord.hiragana ?? currentWord.word;
    final definition =
        _translatedDefinitions[currentWord.id] ?? currentWord.definition;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sentenceQuiz),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1}/$_totalQuestions',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 진행률 바
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _quizWords.length,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            ),

            // 점수 표시
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.score}: $_score',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 문제 유형 표시
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note,
                            size: 20,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.fillInTheBlank,
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 예문 (빈칸 포함)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              _sentenceWithBlank,
                              style: const TextStyle(
                                fontSize: 22,
                                height: 1.8,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_answered) ...[
                              const Divider(height: 32),
                              // 정답 표시
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${l10n.answer}: ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    correctAnswer,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                  if (currentWord.hiragana != null &&
                                      currentWord.kanji != null)
                                    Text(
                                      ' (${currentWord.hiragana})',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // 뜻 표시
                              Text(
                                definition,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 선택지
                    ...List.generate(_options.length, (index) {
                      final option = _options[index];
                      final isSelected = _selectedOption == option;
                      final isCorrect = option == correctAnswer;

                      Color? backgroundColor;
                      Color? borderColor;
                      Color textColor =
                          theme.textTheme.bodyLarge?.color ?? Colors.black;

                      if (_answered) {
                        if (isCorrect) {
                          backgroundColor = Colors.green.withOpacity(0.2);
                          borderColor = Colors.green;
                          textColor = Colors.green[800]!;
                        } else if (isSelected && !isCorrect) {
                          backgroundColor = Colors.red.withOpacity(0.2);
                          borderColor = Colors.red;
                          textColor = Colors.red[800]!;
                        }
                      } else if (isSelected) {
                        backgroundColor = theme.primaryColor.withOpacity(0.1);
                        borderColor = theme.primaryColor;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: backgroundColor ?? theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap:
                                _answered ? null : () => _checkAnswer(option),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: borderColor ?? Colors.grey[300]!,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color:
                                          borderColor?.withOpacity(0.2) ??
                                          Colors.grey[200],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        String.fromCharCode(65 + index),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              borderColor ?? Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  if (_answered && isCorrect)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                  if (_answered && isSelected && !isCorrect)
                                    const Icon(Icons.cancel, color: Colors.red),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // 다음 버튼
            if (_answered)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentIndex < _quizWords.length - 1
                        ? l10n.next
                        : l10n.showResults,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
