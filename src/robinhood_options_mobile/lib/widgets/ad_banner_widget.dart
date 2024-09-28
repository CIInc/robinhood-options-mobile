import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:robinhood_options_mobile/constants.dart';

class AdBannerWidget extends StatefulWidget {
  final AdSize size;
  final bool searchBanner;
  const AdBannerWidget(
      {super.key, this.size = AdSize.banner, this.searchBanner = false});

  @override
  State<StatefulWidget> createState() {
    return _AdBannerWidget();
  }
}

class _AdBannerWidget extends State<AdBannerWidget> {
  late BannerAd _bannerAd;
  bool _bannerReady = false;

  @override
  void initState() {
    super.initState();
    final adUnitId = kDebugMode
        ? Constants.testAdUnit
        : (widget.searchBanner
            ? (Platform.isAndroid
                ? Constants.searchBannerAndroidAdUnit
                : Constants.searchBanneriOSAdUnit)
            : (Platform.isAndroid
                ? Constants.homeBannerAndroidAdUnit
                : Constants.homeBanneriOSAdUnit));
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        // Called when an ad is successfully received.
        onAdLoaded: (Ad ad) {
          debugPrint('Ad loaded.');
          setState(() {
            _bannerReady = true;
          });
        },
        // Called when an ad request failed.
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          // Dispose the ad here to free resources.
          ad.dispose();
          debugPrint('Ad failed to load: $error');
        },
        // Called when an ad opens an overlay that covers the screen.
        onAdOpened: (Ad ad) => debugPrint('Ad opened.'),
        // Called when an ad removes an overlay that covers the screen.
        onAdClosed: (Ad ad) => debugPrint('Ad closed.'),
        // Called when an impression occurs on the ad.
        onAdImpression: (Ad ad) => debugPrint('Ad impression.'),
      ),
    );
    _bannerAd.load();
  }

  @override
  void dispose() {
    super.dispose();
    _bannerAd.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _bannerReady
        ? SizedBox(
            width: _bannerAd.size.width.toDouble(),
            height: _bannerAd.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd),
          )
        : Container();
  }
}
