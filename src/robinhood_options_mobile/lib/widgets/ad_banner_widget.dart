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

class _AdBannerWidget extends State<AdBannerWidget>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  bool _bannerReady = false;
  AdWidget? _adWidget;

  @override
  bool get wantKeepAlive => true;

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
          if (mounted) {
            setState(() {
              _bannerReady = true;
              if (_bannerAd != null) {
                _adWidget = AdWidget(ad: _bannerAd!);
              }
            });
          }
        },
        // Called when an ad request failed.
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('Ad failed to load: $error');
          // Dispose the ad here to free resources.
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _bannerReady = false;
            });
          }
        },
        // Called when an ad opens an overlay that covers the screen.
        onAdOpened: (Ad ad) => debugPrint('Ad opened.'),
        // Called when an ad removes an overlay that covers the screen.
        onAdClosed: (Ad ad) => debugPrint('Ad closed.'),
        // Called when an impression occurs on the ad.
        onAdImpression: (Ad ad) => debugPrint('Ad impression.'),
      ),
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _bannerReady && _bannerAd != null && _adWidget != null
        ? SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: _adWidget,
          )
        : Container();
  }
}
