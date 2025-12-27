import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:jlpt_vocab_app_n1/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/word.dart';
import '../services/translation_service.dart';
import '../services/ad_service.dart';
import '../services/display_service.dart';
import 'word_detail_screen.dart';

class WordListScreen extends StatefulWidget {
  final String? level;
  final bool isFlashcardMode;
  final bool favoritesOnly;

  const WordListScreen({
    super.key,
    this.level,
    this.isFlashcardMode = false,
    this.favoritesOnly = false,
  });

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  List<Word> _words = [];
  List<Word> _allWords = []; // Keep all words for filtering
  bool _isLoading = true;
  int _currentFlashcardIndex = 0;
  late PageController _pageController;
  String _sortOrder = 'alphabetical';
  String? _selectedBandFilter; // Band filter for All Words view
  double _wordFontSize = 1.0;
  bool _showNativeLanguage = true;
  bool _showBandBadge = true; // Band 배지 표시 여부

  final ScrollController _listScrollController = ScrollController();

  Map<int, String> _translatedDefinitions = {};
  Map<int, String> _translatedExamples = {};

  String get _scrollOffsetKey =>
      'word_list_scroll_offset_${widget.level ?? 'all'}';

  String get _positionKey =>
      'word_list_position_${widget.level ?? 'all'}_${widget.isFlashcardMode ? 'flashcard' : 'list'}';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadWords();
    _loadUnlockStatus();
    AdService.instance.loadRewardedAd();
    _loadFontSize();
  }

  Future<void> _loadUnlockStatus() async {
    await AdService.instance.loadUnlockStatus();
    if (mounted) setState(() {});
  }

  Future<void> _restoreScrollPosition() async {
    if (widget.isFlashcardMode) return;
    final prefs = await SharedPreferences.getInstance();
    final position = prefs.getInt(_positionKey) ?? 0;
    if (position > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_listScrollController.hasClients && mounted) {
          _listScrollController.jumpTo(position * 80.0);
        }
      });
    }
  }

  Future<void> _loadRewardedAd() async {
    // 보상형 광고 로드
    AdService.instance.loadRewardedAd();
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wordFontSize = prefs.getDouble('wordFontSize') ?? 1.0;
    });
  }

  // 잠긴 단어인지 확인 (짝수 인덱스 = 2, 4, 6...)
  bool _isWordLocked(int index) {
    // 홀수 단어는 무료, 짝수 단어(2, 4, 6...)는 잠김
    if (index % 2 == 0) return false; // 0, 2, 4... -> 1번, 3번, 5번 단어 (무료)
    return !AdService.instance.isUnlocked; // 1, 3, 5... -> 2번, 4번, 6번 단어 (잠김)
  }

  // 광고 시청 다이얼로그 표시
  void _showUnlockDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.lock, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.lockedContent)),
              ],
            ),
            content: Text(l10n.watchAdToUnlock),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _watchAdToUnlock();
                },
                icon: const Icon(Icons.play_circle_outline),
                label: Text(l10n.watchAd),
              ),
            ],
          ),
    );
  }

  // 광고 시청하여 잠금 해제
  Future<void> _watchAdToUnlock() async {
    final l10n = AppLocalizations.of(context)!;
    final adService = AdService.instance;

    if (!adService.isAdReady) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.adNotReady)));
      adService.loadRewardedAd();
      return;
    }

    await adService.showRewardedAd(
      onRewarded: () async {
        await adService.unlockUntilMidnight();
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.unlockedUntilMidnight)));
        }
      },
    );
  }

  Future<void> _loadWords() async {
    List<Word> words;
    if (widget.favoritesOnly) {
      words = await DatabaseHelper.instance.getFavorites();
    } else if (widget.level != null) {
      words = await DatabaseHelper.instance.getWordsByLevel(widget.level!);
    } else {
      words = await DatabaseHelper.instance.getAllWords();
    }

    final prefs = await SharedPreferences.getInstance();
    final savedPosition = prefs.getInt(_positionKey) ?? 0;

    setState(() {
      _allWords = words; // Keep original list
      _words = words;
      _isLoading = false;
    });

    if (words.isNotEmpty) {
      final position = savedPosition.clamp(0, words.length - 1);
      if (widget.isFlashcardMode) {
        _currentFlashcardIndex = position;
        _pageController = PageController(initialPage: position);
        setState(() {});
      } else {
        // Restore scroll position for list mode
        _restoreScrollPosition();
      }
    }
  }

  void _filterByBand(String? band) {
    setState(() {
      _selectedBandFilter = band;
      if (band == null) {
        _words = List.from(_allWords);
      } else {
        _words = _allWords.where((w) => w.level == band).toList();
      }
      _currentFlashcardIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  Future<void> _savePosition(int position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_positionKey, position);
  }

  Future<void> _loadTranslationForWord(Word word) async {
    if (_translatedDefinitions.containsKey(word.id)) return;

    final translationService = TranslationService.instance;
    await translationService.init();

    if (!translationService.needsTranslation) return;
    if (!mounted) return;

    // ???번역????(API ?�????
    final langCode = translationService.currentLanguage;
    final embeddedDef = word.getEmbeddedTranslation(langCode, 'definition');
    final embeddedEx = word.getEmbeddedTranslation(langCode, 'example');

    if (!mounted) return;
    if (embeddedDef != null && embeddedDef.isNotEmpty) {
      setState(() {
        _translatedDefinitions[word.id] = embeddedDef;
        if (embeddedEx != null && embeddedEx.isNotEmpty) {
          _translatedExamples[word.id] = embeddedEx;
        }
      });
    }
  }

  void _sortWords(String order) {
    final currentWord =
        _words.isNotEmpty ? _words[_currentFlashcardIndex] : null;

    setState(() {
      _sortOrder = order;
      if (order == 'alphabetical') {
        _words.sort(
          (a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()),
        );
      } else if (order == 'random') {
        _words.shuffle();
      }

      if (currentWord != null) {
        final newIndex = _words.indexWhere((w) => w.id == currentWord.id);
        _currentFlashcardIndex = newIndex >= 0 ? newIndex : 0;
      } else {
        _currentFlashcardIndex = 0;
      }

      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentFlashcardIndex);
      }
    });
  }

  Future<void> _toggleFavorite(Word word) async {
    await DatabaseHelper.instance.toggleFavorite(word.id, !word.isFavorite);
    setState(() {
      word.isFavorite = !word.isFavorite;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          word.isFavorite
              ? AppLocalizations.of(context)!.addedToFavorites
              : AppLocalizations.of(context)!.removedFromFavorites,
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'N5':
        return Colors.green;
      case 'N4':
        return Colors.blue;
      case 'N3':
        return Colors.orange;
      case 'N2':
        return Colors.purple;
      case 'N1':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  void _showBandFilterDialog() {
    final l10n = AppLocalizations.of(context)!;
    final bands = [
      {'level': null, 'name': l10n.allWords, 'color': Colors.grey},
      {'level': 'N5', 'name': 'N5', 'color': Colors.green},
      {'level': 'N4', 'name': 'N4', 'color': Colors.blue},
      {'level': 'N3', 'name': 'N3', 'color': Colors.orange},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.levelLearning,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...bands.map(
                  (band) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: band['color'] as Color,
                      radius: 12,
                    ),
                    title: Text(band['name'] as String),
                    trailing:
                        _selectedBandFilter == band['level']
                            ? Icon(
                              Icons.check,
                              color: Theme.of(context).primaryColor,
                            )
                            : null,
                    onTap: () {
                      Navigator.pop(context);
                      _filterByBand(band['level'] as String?);
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  Future<bool> _handleBackPress() async {
    return true;
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (!widget.isFlashcardMode && _listScrollController.hasClients) {
      final itemIndex = (_listScrollController.offset / 80.0).round();
      _savePosition(itemIndex);
    }
    _listScrollController.dispose();
    AdService.instance.dispose();
    if (widget.isFlashcardMode) {
      _savePosition(_currentFlashcardIndex);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String title = l10n.allWords;
    if (widget.level != null) {
      title = l10n.levelWords(widget.level!);
    }
    if (widget.isFlashcardMode) {
      title = l10n.flashcard;
    }

    return Scaffold(
      appBar: AppBar(
        leading:
            widget.isFlashcardMode
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    if (await _handleBackPress()) {
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                )
                : null,
        title: Column(
          children: [
            Text(title),
            if (_selectedBandFilter != null)
              Text(
                _selectedBandFilter!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Band �? ????? 버튼 (All Words 리스???�?
          // Band badge button - disabled for single-level N1 app
          if (false)
            IconButton(
              icon: Icon(
                _showBandBadge ? Icons.label : Icons.label_off,
                color: _showBandBadge ? Theme.of(context).primaryColor : null,
              ),
              tooltip: 'Toggle Band Badge',
              onPressed: () {
                setState(() {
                  _showBandBadge = !_showBandBadge;
                });
              },
            ),
          // Band filter button - disabled for single-level N1 app
          if (false)
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color:
                    _selectedBandFilter != null
                        ? Theme.of(context).primaryColor
                        : null,
              ),
              onPressed: _showBandFilterDialog,
            ),
          if (_words.isNotEmpty && TranslationService.instance.needsTranslation)
            IconButton(
              icon: Icon(
                _showNativeLanguage ? Icons.translate : Icons.language,
                color:
                    _showNativeLanguage ? Theme.of(context).primaryColor : null,
              ),
              onPressed: () {
                setState(() {
                  _showNativeLanguage = !_showNativeLanguage;
                });
              },
            ),
          if (_words.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              onSelected: _sortWords,
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'alphabetical',
                      child: Row(
                        children: [
                          Icon(
                            Icons.sort_by_alpha,
                            color:
                                _sortOrder == 'alphabetical'
                                    ? Theme.of(context).primaryColor
                                    : null,
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.alphabetical),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'random',
                      child: Row(
                        children: [
                          Icon(
                            Icons.shuffle,
                            color:
                                _sortOrder == 'random'
                                    ? Theme.of(context).primaryColor
                                    : null,
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.random),
                        ],
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body: Column(
        children: [
          // 잠금 해제 안내 배너 (잠긴 상태일 때만 표시)
          if (!AdService.instance.isUnlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                ),
              ),
              child: InkWell(
                onTap: _showUnlockDialog,
                child: Row(
                  children: [
                    const Icon(Icons.lock_open, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.watchAdToUnlock,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            color: Colors.deepOrange.shade400,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.watchAd,
                            style: TextStyle(
                              color: Colors.deepOrange.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _words.isEmpty
                    ? Center(child: Text(l10n.cannotLoadWords))
                    : widget.isFlashcardMode
                    ? _buildFlashcardView()
                    : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          final itemIndex = (_listScrollController.offset / 80.0).round();
          _savePosition(itemIndex);
        }
        return false;
      },
      child: ListView.builder(
        controller: _listScrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _words.length,
        itemBuilder: (context, index) {
          final word = _words[index];
          final isLocked = _isWordLocked(index);

          if (!isLocked) {
            _loadTranslationForWord(word);
          }

          final definition =
              isLocked
                  ? '🔒 ••••••••••••••'
                  : (_showNativeLanguage &&
                          _translatedDefinitions.containsKey(word.id)
                      ? _translatedDefinitions[word.id]!
                      : word.definition);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: () async {
                // 잠긴 단어면 광고 다이얼로그 표시
                if (isLocked) {
                  _showUnlockDialog();
                  return;
                }

                // Create a copy of the list to prevent issues with sorting/filtering
                final wordListCopy = List<Word>.from(_words);
                final result = await Navigator.push<int>(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => WordDetailScreen(
                          word: word,
                          wordList: wordListCopy,
                          currentIndex: index,
                        ),
                  ),
                );
                if (result != null && mounted) {
                  // 항상 반환된 위치로 스크롤하고 저장
                  _savePosition(result);
                  if (result != index && _listScrollController.hasClients) {
                    _listScrollController.animateTo(
                      result * 80.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                }
              },
              title: Row(
                children: [
                  if (isLocked)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.lock, size: 16, color: Colors.orange),
                    ),
                  Expanded(
                    child: Text(
                      isLocked
                          ? '${word.word.substring(0, 1)}••••'
                          : word.getDisplayWord(
                            displayMode: DisplayService.instance.displayMode,
                          ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16 * _wordFontSize,
                        color: isLocked ? Colors.grey : null,
                      ),
                    ),
                  ),
                  // Band 배지: All Words에서만 표시
                  if (false) // Level badge disabled for single-level app
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getLevelColor(word.level),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        word.level,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (false &&
                      word.partOfSpeech.isNotEmpty &&
                      word.partOfSpeech != 'unknown') ...[
                    Row(
                      children: [
                        Text(
                          word.partOfSpeech,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    definition,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14 * _wordFontSize,
                      color: isLocked ? Colors.grey : null,
                    ),
                  ),
                ],
              ),
              trailing:
                  isLocked
                      ? const Icon(Icons.lock_outline, color: Colors.orange)
                      : IconButton(
                        icon: Icon(
                          word.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: word.isFavorite ? Colors.red : null,
                        ),
                        onPressed: () => _toggleFavorite(word),
                      ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlashcardView() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_currentFlashcardIndex + 1} / ${_words.length}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        // Flashcard
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _words.length,
            onPageChanged: (index) {
              setState(() {
                _currentFlashcardIndex = index;
              });
              _savePosition(index);
              _loadTranslationForWord(_words[index]);
            },
            itemBuilder: (context, index) {
              final word = _words[index];
              _loadTranslationForWord(word);

              final definition =
                  _showNativeLanguage &&
                          _translatedDefinitions.containsKey(word.id)
                      ? _translatedDefinitions[word.id]!
                      : word.definition;
              final example =
                  _showNativeLanguage &&
                          _translatedExamples.containsKey(word.id)
                      ? _translatedExamples[word.id]!
                      : word.example;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FlipCard(
                  direction: FlipDirection.HORIZONTAL,
                  front: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            _getLevelColor(word.level),
                            _getLevelColor(
                              word.level,
                            ).withAlpha((0.7 * 255).toInt()),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (false)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(
                                        (0.2 * 255).toInt(),
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      word.partOfSpeech,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: Icon(
                                    word.isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color:
                                        word.isFavorite
                                            ? Colors.red
                                            : Colors.white,
                                  ),
                                  onPressed: () => _toggleFavorite(word),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              word.getDisplayWord(
                                displayMode:
                                    DisplayService.instance.displayMode,
                              ),
                              style: TextStyle(
                                fontSize: 28 * _wordFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            // Level badge removed for single-level app
                            const SizedBox.shrink(),
                            const Spacer(),
                            Text(
                              l10n.tapToFlip,
                              style: TextStyle(
                                color: Colors.white.withAlpha(
                                  (0.8 * 255).toInt(),
                                ),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  back: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 40,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.definition,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            definition,
                            style: TextStyle(
                              fontSize: 18 * _wordFontSize,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            l10n.example,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            word.example, // Always show example in English
                            style: TextStyle(
                              fontSize: 16 * _wordFontSize,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Navigation buttons
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed:
                    _currentFlashcardIndex > 0
                        ? () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                        : null,
                icon: const Icon(Icons.chevron_left),
                label: Text(l10n.previous),
              ),
              ElevatedButton.icon(
                onPressed:
                    _currentFlashcardIndex < _words.length - 1
                        ? () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                        : null,
                icon: const Icon(Icons.chevron_right),
                label: Text(l10n.next),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
