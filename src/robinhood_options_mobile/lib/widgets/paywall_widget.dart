import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/subscription_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallWidget extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDocRef;
  final VoidCallback onSuccess;
  final VoidCallback? onDismiss;

  const PaywallWidget({
    super.key,
    required this.user,
    required this.userDocRef,
    required this.onSuccess,
    this.onDismiss,
  });

  @override
  State<PaywallWidget> createState() => _PaywallWidgetState();
}

class _PaywallWidgetState extends State<PaywallWidget> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final ScrollController _scrollController = ScrollController();
  List<ProductDetails> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    // Re-verify subscription status on init
    _checkStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkStatus() {
    if (_subscriptionService.isSubscriptionActive(widget.user)) {
      widget.onSuccess();
    }
  }

  @override
  void didUpdateWidget(PaywallWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _checkStatus();
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _subscriptionService.loadProducts();
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startTrial() async {
    setState(() => _isLoading = true);
    try {
      await _subscriptionService.startTrial(widget.user, widget.userDocRef);
      // The parent widget should rebuild with the new user state and call onSuccess or hide this widget
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to start trial: $e";
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    try {
      await _subscriptionService.restorePurchases();
      // Wait a moment for listeners to fire
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Purchases restored. Checking status...')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Restore failed: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _subscribe(ProductDetails product) async {
    _subscriptionService.buySubscription(product);
    // Feedback is handled by IAP UI and subsequent stream events
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isTrialEligible = _subscriptionService.isTrialEligible(widget.user);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Feature list for the paywall
    final features = [
      {'icon': Icons.trending_up, 'text': 'AI-Powered Trade Signals'},
      {
        'icon': Icons.candlestick_chart,
        'text': 'Advanced Technical Indicators'
      },
      {'icon': Icons.smart_toy, 'text': 'Automated Trading Bots'},
      {'icon': Icons.psychology, 'text': 'AI Trading Coach & Insights'},
      {'icon': Icons.history, 'text': 'Limitless Backtesting'},
    ];

    final testimonials = [
      {
        'text':
            "The AI signals are incredibly accurate. Paid for itself in one trade!",
        'author': "Alex T."
      },
      {
        'text':
            "Finally, a tool that helps me manage risk properly. Love the coaching.",
        'author': "Sarah M."
      },
      {
        'text':
            "Backtesting is a game changer. I refined my strategy in minutes.",
        'author': "J.D."
      },
    ];

    final faqs = [
      {
        'question': 'Can I cancel anytime?',
        'answer':
            'Yes, you can cancel your subscription at any time through your device settings.'
      },
      {
        'question': 'What is included in the trial?',
        'answer':
            'The 14-day free trial gives you full access to all Pro features.'
      },
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surface,
                  colorScheme.primaryContainer.withOpacity(0.3),
                  colorScheme.surface,
                ],
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Close button if available
                          if (widget.onDismiss != null ||
                              Navigator.canPop(context))
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: widget.onDismiss ??
                                    () => Navigator.of(context).pop(),
                              ),
                            )
                          else
                            const SizedBox(
                                height: 48), // Spacer if no close button

                          FadeInSlide(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.secondary,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          colorScheme.primary.withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.star,
                                    size: 64, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          FadeInSlide(
                            delay: const Duration(milliseconds: 100),
                            child: Column(
                              children: [
                                Text(
                                  'Upgrade to Pro',
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Unlock the full potential of your trading with advanced AI tools.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.7),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Features List
                          ...features.asMap().entries.map((entry) {
                            final index = entry.key;
                            final feature = entry.value;
                            return FadeInSlide(
                              delay:
                                  Duration(milliseconds: 200 + (index * 100)),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(feature['icon'] as IconData,
                                          color: colorScheme.primary, size: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        feature['text'] as String,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 32),

                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.red),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (isTrialEligible) ...[
                            FadeInSlide(
                              delay: const Duration(milliseconds: 600),
                              child: _buildPrimaryButton(
                                context: context,
                                onTap: _startTrial,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      'Start 14-Day Free Trial',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Then \$9.99/month. Cancel anytime.',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            if (_products.isNotEmpty)
                              ..._products.map((product) {
                                final cleanTitle =
                                    product.title.split('(').first.trim();
                                return FadeInSlide(
                                  delay: const Duration(milliseconds: 600),
                                  child: _buildPrimaryButton(
                                    context: context,
                                    onTap: () => _subscribe(product),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(cleanTitle,
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white)),
                                              Text(product.description,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.8),
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          product.price,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              })
                            else if (!_isLoading)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No subscription products found. Please contact support.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                          ],

                          const SizedBox(height: 24),

                          // Testimonials
                          FadeInSlide(
                            delay: const Duration(milliseconds: 800),
                            child: SizedBox(
                              height: 120,
                              child: PageView(
                                children: testimonials
                                    .map((t) => Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: colorScheme
                                                .surfaceContainerHighest
                                                .withOpacity(0.5),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '"${t['text']}"',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    fontStyle:
                                                        FontStyle.italic),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "- ${t['author']}",
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // FAQ
                          FadeInSlide(
                            delay: const Duration(milliseconds: 1000),
                            child: Column(
                              children: faqs
                                  .map((faq) => Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: colorScheme.outline
                                                  .withOpacity(0.2)),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ExpansionTile(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          collapsedShape:
                                              RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                          title: Text(faq['question']!,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600)),
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      16, 0, 16, 16),
                                              child: Text(faq['answer']!,
                                                  style: TextStyle(
                                                      color: colorScheme
                                                          .onSurface
                                                          .withOpacity(0.7),
                                                      height: 1.4)),
                                            )
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),

                          const Divider(),

                          // Disclaimer for App Store Compliance
                          FadeInSlide(
                            delay: const Duration(milliseconds: 1200),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                'Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period. Your account will be charged for renewal within 24-hours prior to the end of the current period. You can manage and cancel your subscriptions in your Account Settings after purchase.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),

                          FadeInSlide(
                            delay: const Duration(milliseconds: 1200),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: _restorePurchases,
                                  child: const Text('Restore Purchases',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ),
                                const Text('•',
                                    style: TextStyle(color: Colors.grey)),
                                TextButton(
                                  onPressed: () => _launchUrl(
                                      'https://cidevelop.com/realizealpha/terms.html'),
                                  child: const Text('Terms',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ),
                                const Text('•',
                                    style: TextStyle(color: Colors.grey)),
                                TextButton(
                                  onPressed: () => _launchUrl(
                                      'https://cidevelop.com/privacy.html'),
                                  child: const Text('Privacy',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required BuildContext context,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  const FadeInSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 600),
    this.offset =
        const Offset(0, 0.2), // Slide up by 20% of child height roughly
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
