import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/constants.dart';

class WelcomeWidget extends StatefulWidget {
  final VoidCallback? onLogin;
  final String? message;
  final String? title;
  final String? actionLabel;
  final bool showFeatures;
  final VoidCallback? onExploreDemo;

  const WelcomeWidget({
    super.key,
    this.onLogin,
    this.message,
    this.title,
    this.actionLabel,
    this.showFeatures = true,
    this.onExploreDemo,
  });

  @override
  State<WelcomeWidget> createState() => _WelcomeWidgetState();
}

class _WelcomeWidgetState extends State<WelcomeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  final List<_FeatureItem> _features = const [
    _FeatureItem(
      icon: Icons.smart_toy_rounded,
      accentColor: Color(0xFF6366F1),
      title: 'Quantitative Auto-Trading',
      description:
          '19-indicator correlation engine with automated RiskGuard execution and multi-timeframe signals.',
    ),
    _FeatureItem(
      icon: Icons.waterfall_chart_rounded,
      accentColor: Color(0xFF06B6D4),
      title: 'Real-Time Options Flow',
      description:
          'Institutional whale tracking, golden sweep detection, smart flags, and premium sentiment.',
    ),
    _FeatureItem(
      icon: Icons.candlestick_chart_rounded,
      accentColor: Color(0xFFF59E0B),
      title: 'Gamma Exposure (GEX) & Walls',
      description:
          'Dealer positioning, 0DTE GEX profiles, Call/Put walls, and real-time strike pinning gauges.',
    ),
    _FeatureItem(
      icon: Icons.groups_rounded,
      accentColor: Color(0xFF3B82F6),
      title: 'Investor Groups & Copy Trading',
      description:
          'Collaborative watchlists, real-time messaging, performance leaderboards, and auto-copying.',
    ),
    _FeatureItem(
      icon: Icons.science_rounded,
      accentColor: Color(0xFF10B981),
      title: 'Paper Trading & Backtesting',
      description:
          'Zero-risk strategy simulation with historical bar-by-bar backtesting and in-depth performance analytics.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo Hero with subtle glow
                  Center(
                    child: Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainerHighest
                            : colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.15),
                            blurRadius: 28,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Brand Tagline Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "AI & Quantitative Trading Platform",
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // App Title
                  Text(
                    widget.title ?? "Welcome to ${Constants.appTitle}",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    "Algorithmic execution, institutional options flow, gamma analytics, and multi-brokerage portfolio management.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Context Message Banner (e.g. session expired, info)
                  if (widget.message != null && widget.message!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.errorContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colorScheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.message!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Feature Showcase Cards
                  if (widget.showFeatures) ...[
                    Text(
                      "Key Capabilities",
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._features.map((feature) => _buildFeatureTile(
                          context,
                          feature: feature,
                          isDark: isDark,
                          colorScheme: colorScheme,
                          theme: theme,
                        )),
                    const SizedBox(height: 20),

                    // Brokerage Integrations Ecosystem
                    _buildSupportedBrokers(context, colorScheme, theme, isDark),
                    const SizedBox(height: 28),
                  ],

                  // Action Buttons
                  if (widget.onLogin != null) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      label: Text(
                        widget.actionLabel ??
                            (widget.message != null
                                ? "Reconnect Account"
                                : "Link Brokerage Account"),
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      onPressed: widget.onLogin,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (widget.onExploreDemo != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      label: const Text(
                        "Explore Demo / Paper Mode",
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.science_outlined, size: 20),
                      onPressed: widget.onExploreDemo,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Security & Non-Custodial Footer
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "Bank-grade 256-bit encryption • Direct OAuth • Non-custodial",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.8),
                              fontSize: 11.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context, {
    required _FeatureItem feature,
    required bool isDark,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHigh
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: feature.accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              feature.icon,
              size: 22,
              color: feature.accentColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  feature.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportedBrokers(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
    bool isDark,
  ) {
    final brokers = const [
      _BrokerChip(
        label: 'Robinhood',
        icon: Icons.account_balance_wallet_rounded,
        color: Color(0xFF00C805),
      ),
      _BrokerChip(
        label: 'Schwab',
        icon: Icons.account_balance_rounded,
        color: Color(0xFF00A3E0),
      ),
      _BrokerChip(
        label: 'Fidelity',
        icon: Icons.trending_up_rounded,
        color: Color(0xFF43A047),
      ),
      _BrokerChip(
        label: 'Paper Trading',
        icon: Icons.science_rounded,
        color: Color(0xFF3B82F6),
      ),
      _BrokerChip(
        label: 'Demo Mode',
        icon: Icons.computer_rounded,
        color: Color(0xFF8B5CF6),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainer
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hub_outlined,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                "Multi-Brokerage Ecosystem",
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: brokers
                .map(
                  (b) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: b.color.withValues(alpha: isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: b.color.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(b.icon, size: 14, color: b.color),
                        const SizedBox(width: 6),
                        Text(
                          b.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? b.color.withValues(alpha: 0.95)
                                : b.color.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
  });
}

class _BrokerChip {
  final String label;
  final IconData icon;
  final Color color;

  const _BrokerChip({
    required this.label,
    required this.icon,
    required this.color,
  });
}
