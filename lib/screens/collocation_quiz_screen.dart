import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jlpt_vocab_app_n1/l10n/generated/app_localizations.dart';
import '../services/ad_service.dart';
import '../services/translation_service.dart';

/// 연어 매칭 퀴즈 화면
/// 명사와 어울리는 동사 선택
class CollocationQuizScreen extends StatefulWidget {
  const CollocationQuizScreen({super.key});

  @override
  State<CollocationQuizScreen> createState() => _CollocationQuizScreenState();
}

class _CollocationQuizScreenState extends State<CollocationQuizScreen> {
  List<Map<String, dynamic>> _collocations = [];
  List<Map<String, dynamic>> _quizItems = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _score = 0;
  final int _totalQuestions = 10;
  String? _selectedOption;
  bool _answered = false;
  List<String> _options = [];

  @override
  void initState() {
    super.initState();
    _loadCollocations();
  }

  Future<void> _loadCollocations() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/collocations.json',
      );
      final List<dynamic> data = json.decode(response);

      final collocations = data.cast<Map<String, dynamic>>();
      collocations.shuffle();

      setState(() {
        _collocations = collocations;
        _quizItems = collocations.take(_totalQuestions).toList();
        _isLoading = false;
        _generateOptions();
      });
    } catch (e) {
      print('Error loading collocations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _generateOptions() {
    if (_quizItems.isEmpty || _currentIndex >= _quizItems.length) return;

    final currentItem = _quizItems[_currentIndex];
    final correctVerb = currentItem['correct_verb'] as String;
    final wrongVerbs = (currentItem['wrong_verbs'] as List).cast<String>();

    _options = [correctVerb, ...wrongVerbs.take(3)]..shuffle();
  }

  void _checkAnswer(String selected) {
    if (_answered) return;

    final currentItem = _quizItems[_currentIndex];
    final correctVerb = currentItem['correct_verb'] as String;

    setState(() {
      _answered = true;
      _selectedOption = selected;
      if (selected == correctVerb) {
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
        _generateOptions();
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
    _collocations.shuffle();
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _answered = false;
      _selectedOption = null;
      _quizItems = _collocations.take(_totalQuestions).toList();
      _generateOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.collocationQuiz)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_quizItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.collocationQuiz)),
        body: Center(child: Text(l10n.noExamplesAvailable)),
      );
    }

    final currentItem = _quizItems[_currentIndex];
    final noun = currentItem['noun'] as String;
    final nounReading = currentItem['noun_reading'] as String;

    // 언어 설정에 따른 필드 선택
    final lang = TranslationService.instance.currentLanguage;
    final meaningSuffix =
        lang == 'ko'
            ? '_ko'
            : lang == 'zh'
            ? '_zh'
            : '_en';
    final nounMeaning =
        currentItem['noun_meaning$meaningSuffix'] as String? ??
        currentItem['noun_meaning_ko'] as String;
    final correctVerb = currentItem['correct_verb'] as String;
    final fullExpression = currentItem['full_expression'] as String;
    final meaningKo =
        currentItem['meaning$meaningSuffix'] as String? ??
        currentItem['meaning_ko'] as String;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.collocationQuiz),
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
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link, size: 20, color: Colors.teal),
                          const SizedBox(width: 8),
                          Text(
                            l10n.collocationQuiz,
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 문제 카드
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
                              l10n.selectMatchingVerb,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 명사 표시
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  noun,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('を', style: TextStyle(fontSize: 36)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.primaryColor,
                                      width: 2,
                                      style: BorderStyle.solid,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '？',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '($nounReading) $nounMeaning',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_answered) ...[
                              const Divider(height: 32),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      fullExpression,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      meaningKo,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 선택지들
                    ...List.generate(_options.length, (index) {
                      final option = _options[index];
                      final isSelected = _selectedOption == option;
                      final isCorrect = option == correctVerb;

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
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w500,
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
                    _currentIndex < _quizItems.length - 1
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
