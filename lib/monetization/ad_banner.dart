import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key, required this.enabled});

  final bool enabled;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  static const String _testBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  BannerAd? _banner;
  bool _loaded = false;

  bool get _isTestEnvironment {
    if (kIsWeb) {
      return false;
    }
    try {
      final bindingStr = WidgetsBinding.instance.toString();
      if (bindingStr.contains('Test')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _load();
    }
  }

  Future<void> _load() async {
    _banner?.dispose();
    _banner = null;
    _loaded = false;

    if (!widget.enabled || _isTestEnvironment || !mounted) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }

    BannerAd? ad;
    ad = BannerAd(
      adUnitId: _testBannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _banner = ad;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (!widget.enabled || !_loaded || banner == null) {
      return const SizedBox.shrink();
    }
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: banner.size.width.toDouble(),
        height: banner.size.height.toDouble(),
        child: AdWidget(ad: banner),
      ),
    );
  }
}