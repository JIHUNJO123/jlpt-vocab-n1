import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jlpt_vocab_app_n1/l10n/generated/app_localizations.dart';
import '../services/ad_service.dart';
import '../services/translation_service.dart';

/// 뉘앙스 대결 퀴즈 화면
/// 유의어 중 문맥에 맞는 단어 선택
class SynonymQuizScreen extends StatefulWidget {
  const SynonymQuizScreen({super.key});

  @override
  State<SynonymQuizScreen> createState() => _SynonymQuizScreenState();
}

class _SynonymQuizScreenState extends State<SynonymQuizScreen> {
  List<Map<String, dynamic>> _synonyms = [];
  List<Map<String, dynamic>> _quizItems = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _score = 0;
  final int _totalQuestions = 10;
  int? _selectedOption;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _loadSynonyms();
  }

  Future<void> _loadSynonyms() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/synonyms.json',
      );
      final List<dynamic> data = json.decode(response);

      final synonyms = data.cast<Map<String, dynamic>>();
      synonyms.shuffle();

      setState(() {
        _synonyms = synonyms;
        _quizItems = synonyms.take(_totalQuestions).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading synonyms: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkAnswer(int selected) {
    if (_answered) return;

    final currentItem = _quizItems[_currentIndex];
    final correct = currentItem['correct'] as int;

    setState(() {
      _answered = true;
      _selectedOption = selected;
      if (selected == correct) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _quizItems.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOption = null;
      });
    } else {
      _showResultDialog();
    }
  }

  void _showResultDialog() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final percentage = (_score / _quizItems.length * 100).round();

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
                  '$_score / ${_quizItems.length}',
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
    _synonyms.shuffle();
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _answered = false;
      _selectedOption = null;
      _quizItems = _synonyms.take(_totalQuestions).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.synonymQuiz)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_quizItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.synonymQuiz)),
        body: Center(child: Text(l10n.noExamplesAvailable)),
      );
    }

    final currentItem = _quizItems[_currentIndex];
    final word1 = currentItem['word1'] as String;
    final word2 = currentItem['word2'] as String;
    final reading1 = currentItem['reading1'] as String;
    final reading2 = currentItem['reading2'] as String;

    // 언어 설정에 따른 필드 선택
    final lang = TranslationService.instance.currentLanguage;
    final meaningSuffix =
        lang == 'ko'
            ? '_ko'
            : lang == 'zh'
            ? '_zh'
            : '_en';
    final meaning1 =
        currentItem['meaning1$meaningSuffix'] as String? ??
        currentItem['meaning1_ko'] as String;
    final meaning2 =
        currentItem['meaning2$meaningSuffix'] as String? ??
        currentItem['meaning2_ko'] as String;
    final example = currentItem['example'] as String;
    final correct = currentItem['correct'] as int;
    final explanation =
        currentItem['explanation$meaningSuffix'] as String? ??
        currentItem['explanation_ko'] as String;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.synonymQuiz),
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
              value: (_currentIndex + 1) / _quizItems.length,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            ),

            // 점수 표시
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 24),
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
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.compare_arrows,
                            size: 20,
                            color: Colors.purple,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.synonymQuiz,
                            style: const TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 예문 카드
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
                              example,
                              style: const TextStyle(
                                fontSize: 24,
                                height: 1.8,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_answered) ...[
                              const Divider(height: 32),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  explanation,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue[800],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 선택지 1
                    _buildOptionCard(
                      optionNumber: 1,
                      word: word1,
                      reading: reading1,
                      meaning: meaning1,
                      isCorrect: correct == 1,
                      theme: theme,
                    ),
                    const SizedBox(height: 16),

                    // 선택지 2
                    _buildOptionCard(
                      optionNumber: 2,
                      word: word2,
                      reading: reading2,
                      meaning: meaning2,
                      isCorrect: correct == 2,
                      theme: theme,
                    ),
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
                    _currentIndex < _quizItems.length - 1
                        ? AppLocalizations.of(context)!.next
                        : AppLocalizations.of(context)!.showResults,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required int optionNumber,
    required String word,
    required String reading,
    required String meaning,
    required bool isCorrect,
    required ThemeData theme,
  }) {
    final isSelected = _selectedOption == optionNumber;

    Color? backgroundColor;
    Color? borderColor;

    if (_answered) {
      if (isCorrect) {
        backgroundColor = Colors.green.withOpacity(0.2);
        borderColor = Colors.green;
      } else if (isSelected && !isCorrect) {
        backgroundColor = Colors.red.withOpacity(0.2);
        borderColor = Colors.red;
      }
    } else if (isSelected) {
      backgroundColor = theme.primaryColor.withOpacity(0.1);
      borderColor = theme.primaryColor;
    }

    return Material(
      color: backgroundColor ?? theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _answered ? null : () => _checkAnswer(optionNumber),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor ?? Colors.grey[300]!,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: borderColor?.withOpacity(0.2) ?? Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$optionNumber',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: borderColor ?? Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          word,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($reading)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meaning,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              if (_answered && isCorrect)
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
              if (_answered && isSelected && !isCorrect)
                const Icon(Icons.cancel, color: Colors.red, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
