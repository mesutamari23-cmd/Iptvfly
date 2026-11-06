import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// أبقِ وضع الاختبار مفعّلاً أثناء التطوير. لا تحوّله إلى false إلا بعد
/// اكتمال مراجعة AdMob، والتحقق من موافقة الخصوصية، ونشر نسخة الإنتاج.
const bool kTestAds = true;
const String kBannerId = 'ca-app-pub-8292052707705243/3492950965';
// ضع هنا معرّف وحدة إعلان بيني (Interstitial) عند إنشائها. فارغ = معطّل
const String kInterstitialId = '';

String get _bannerUnit =>
    kTestAds ? 'ca-app-pub-3940256099942544/6300978111' : kBannerId;
String get _interUnit =>
    kTestAds ? 'ca-app-pub-3940256099942544/1033173712' : kInterstitialId;

class Ads {
  static bool _ready = false;
  static InterstitialAd? _ad;
  static int _opens = 0;
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      await MobileAds.instance.initialize();
      _ready = true;
      _load();
    } catch (_) {}
  }

  static void _load() {
    if (!_ready || _interUnit.isEmpty) return;
    InterstitialAd.load(
      adUnitId: _interUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (a) => _ad = a,
        onAdFailedToLoad: (_) => _ad = null,
      ),
    );
  }

  /// إعلان بيني: كل 3 فتحات للمحتوى وبفاصل لا يقل عن 3 دقائق.
  /// لا يُستدعى أبداً أثناء التشغيل.
  static Future<void> maybeInterstitial() async {
    _opens++;
    final ad = _ad;
    if (ad == null) return;
    if (_opens % 3 != 0) return;
    if (DateTime.now().difference(_last) < const Duration(minutes: 3)) return;

    _ad = null;
    _last = DateTime.now();
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _load();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _load();
        if (!done.isCompleted) done.complete();
      },
    );
    await ad.show();
    await done.future.timeout(const Duration(seconds: 60), onTimeout: () {});
  }
}

/// بانر صغير: لا يظهر شيئاً إذا لم يتوفر إعلان (مثلاً على التلفزيون)
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});
  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return;
    final ad = BannerAd(
      adUnitId: _bannerUnit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (a) {
          if (mounted) {
            setState(() => _ad = a as BannerAd);
          } else {
            a.dispose();
          }
        },
        onAdFailedToLoad: (a, _) => a.dispose(),
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _ad;
    if (a == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: SizedBox(
          width: a.size.width.toDouble(),
          height: a.size.height.toDouble(),
          child: AdWidget(ad: a),
        ),
      ),
    );
  }
}
