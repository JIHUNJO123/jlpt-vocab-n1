import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  static AdService get instance => _instance;
  AdService._internal();

  bool _isInitialized = false;
  bool _adsRemoved = false;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;

  // JLPT Step N1 광고 ID
  // Android
  static const String _androidBannerId =
      'ca-app-pub-5837885590326347/2049559122';
  static const String _androidInterstitialId =
      'ca-app-pub-5837885590326347/6483628156';
  // iOS
  static const String _iosBannerId = 'ca-app-pub-5837885590326347/2049559122';
  static const String _iosInterstitialId =
      'ca-app-pub-5837885590326347/6483628156';

  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return _androidBannerId;
    } else if (Platform.isIOS) {
      return _iosBannerId;
    }
    return '';
  }

  String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return _androidInterstitialId;
    } else if (Platform.isIOS) {
      return _iosInterstitialId;
    }
    return '';
  }

  bool get isInitialized => _isInitialized;
  bool get adsRemoved => _adsRemoved;
  bool get isBannerAdLoaded => _isBannerAdLoaded;
  bool get isInterstitialAdLoaded => _isInterstitialAdLoaded;
  BannerAd? get bannerAd => _bannerAd;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool('ads_removed') ?? false;

    if (_adsRemoved) {
      _isInitialized = true;
      return;
    }

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _isInitialized = true;
      return;
    }

    // JLPT Step N1 AdMob App ID
    final appId = Platform.isAndroid
        ? 'ca-app-pub-5837885590326347~2753827200'  // Android
        : 'ca-app-pub-5837885590326347~4163768337'; // iOS

    await MobileAds.instance.initialize();
    _isInitialized = true;
  }

  Future<void> loadBannerAd({Function()? onLoaded}) async {
    debugPrint('loadBannerAd called');
    debugPrint('  adsRemoved: $_adsRemoved');

    if (_adsRemoved) {
      debugPrint('  Ads removed, skipping banner load');
      return;
    }
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('  Not mobile platform, skipping');
      return;
    }

    _bannerAd?.dispose();
    _isBannerAdLoaded = false;

    debugPrint('  Loading banner with adUnitId: $bannerAdUnitId');

    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('  BannerAd loaded successfully!');
          _isBannerAdLoaded = true;
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '  BannerAd failed to load: ${error.code} - ${error.message}',
          );
          ad.dispose();
          _isBannerAdLoaded = false;
        },
      ),
    );

    await _bannerAd!.load();
  }

  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdLoaded = false;
  }

  Future<void> loadInterstitialAd() async {
    if (_adsRemoved) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;

          _interstitialAd!
              .fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialAdLoaded = false;
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialAdLoaded = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          _isInterstitialAdLoaded = false;
        },
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    if (_adsRemoved) return;
    if (!_isInterstitialAdLoaded || _interstitialAd == null) return;

    await _interstitialAd!.show();
  }

  void disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdLoaded = false;
  }

  Future<void> removeAds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ads_removed', true);
    _adsRemoved = true;
    disposeBannerAd();
    disposeInterstitialAd();
  }

  Future<void> restoreAdsRemoved() async {
    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool('ads_removed') ?? false;
    if (_adsRemoved) {
      disposeBannerAd();
      disposeInterstitialAd();
    }
  }
}
