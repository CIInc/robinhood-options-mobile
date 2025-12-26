import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';

/// A reusable badge widget that displays the current auto-trade status.
///
/// Shows:
/// - Auto-trade countdown timer when enabled but waiting
/// - Active trading status with trade count (e.g., "3/5")
/// - Emergency stop indicator
/// - Color-coded states: amber (waiting), green (active), red (stopped)
/// - Animated scale pulse when auto-trading is active
///
/// Tapping the badge opens the Agentic Trading Settings screen.
/// Long-pressing allows quick toggling of Emergency Stop.
class AutoTradeStatusBadgeWidget extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final IBrokerageService? service;

  const AutoTradeStatusBadgeWidget({
    super.key,
    this.user,
    this.userDocRef,
    required this.service,
  });

  @override
  State<AutoTradeStatusBadgeWidget> createState() =>
      _AutoTradeStatusBadgeWidgetState();
}

class _AutoTradeStatusBadgeWidgetState extends State<AutoTradeStatusBadgeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _wasActive = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleLongPress(BuildContext context, AgenticTradingProvider provider) {
    HapticFeedback.heavyImpact();
    final isEmergencyStop = provider.emergencyStopActivated;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEmergencyStop ? 'Resume Trading?' : 'Emergency Stop?'),
        content: Text(isEmergencyStop
            ? 'This will deactivate the emergency stop and allow auto-trading to resume.'
            : 'This will immediately halt all automated trading activities.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isEmergencyStop ? Colors.green : Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              if (isEmergencyStop) {
                provider.deactivateEmergencyStop();
              } else {
                provider.activateEmergencyStop(userDocRef: widget.userDocRef);
              }
            },
            child: Text(isEmergencyStop ? 'Resume' : 'STOP TRADING'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AgenticTradingProvider>(
      builder: (context, agenticTradingProvider, child) {
        final config = agenticTradingProvider.config;
        final autoTradeEnabled = config['autoTradeEnabled'] as bool? ?? false;

        if (!autoTradeEnabled) {
          return const SizedBox.shrink();
        }

        final isAutoTrading = agenticTradingProvider.showAutoTradingVisual;
        final isEmergencyStop = agenticTradingProvider.emergencyStopActivated;

        // Animation logic
        final shouldAnimate = isAutoTrading || isEmergencyStop;
        if (shouldAnimate) {
          final newDuration = isEmergencyStop
              ? const Duration(milliseconds: 800)
              : const Duration(milliseconds: 1500);

          if (_animationController.duration != newDuration) {
            _animationController.duration = newDuration;
            if (_animationController.isAnimating) {
              _animationController.repeat(reverse: true);
            }
          }

          if (!_wasActive) {
            _animationController.repeat(reverse: true);
            HapticFeedback.mediumImpact();
            _wasActive = true;
          }
        } else if (_wasActive) {
          _animationController.stop();
          _animationController.reset();
          _wasActive = false;
        }

        final status = _getStatusAttributes(context, agenticTradingProvider);

        // Calculate progress for countdown if in waiting state
        double? progressValue;
        if (status.title == 'Auto On') {
          final countdown = agenticTradingProvider.autoTradeCountdownSeconds;
          // Assuming 5 minute cycle (300 seconds)
          progressValue = (300.0 - countdown) / 300.0;
          if (progressValue < 0) progressValue = 0;
          if (progressValue > 1) progressValue = 1;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Tooltip(
            message: status.tooltip,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (widget.user != null && widget.userDocRef != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AgenticTradingSettingsWidget(
                          user: widget.user!,
                          userDocRef: widget.userDocRef!,
                          service: widget.service,
                        ),
                      ),
                    );
                  }
                },
                onLongPress: () =>
                    _handleLongPress(context, agenticTradingProvider),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    double scale = _isPressed ? 0.95 : 1.0;
                    if (isAutoTrading) {
                      scale *= _scaleAnimation.value;
                    }

                    return Transform.scale(
                      scale: scale,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              status.color.withOpacity(0.15),
                              status.color.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: status.color.withOpacity(
                                (isAutoTrading || isEmergencyStop)
                                    ? _opacityAnimation.value
                                    : 0.3),
                            width: 1,
                          ),
                          boxShadow: (isAutoTrading || isEmergencyStop)
                              ? [
                                  BoxShadow(
                                    color: status.color.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAutoTrading)
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      status.color),
                                ),
                              )
                            else if (status.title == 'Auto On')
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                      begin: 0, end: progressValue ?? 0),
                                  duration: const Duration(milliseconds: 1000),
                                  builder: (context, value, _) =>
                                      CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 2,
                                    backgroundColor:
                                        status.color.withOpacity(0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        status.color),
                                  ),
                                ),
                              )
                            else
                              Icon(
                                status.icon,
                                size: 14,
                                color: status.color,
                              ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    status.title.toUpperCase(),
                                    key: ValueKey('title_${status.title}'),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: status.color.withOpacity(0.9),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    status.subtitle,
                                    key:
                                        ValueKey('subtitle_${status.subtitle}'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: status.color,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _StatusAttributes _getStatusAttributes(
      BuildContext context, AgenticTradingProvider provider) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isAutoTrading = provider.showAutoTradingVisual;
    final emergencyStop = provider.emergencyStopActivated;
    final dailyCount = provider.dailyTradeCount;
    final dailyLimit = provider.config['dailyTradeLimit'] as int? ?? 5;
    final countdownSeconds = provider.autoTradeCountdownSeconds;

    if (emergencyStop) {
      return _StatusAttributes(
        title: 'Stopped',
        subtitle: 'EMERGENCY',
        color: isLight ? Colors.red.shade700 : Colors.red,
        icon: Icons.stop_circle,
        tooltip: 'Emergency Stop Active\nLong press to resume',
      );
    } else if (dailyCount >= dailyLimit) {
      return _StatusAttributes(
        title: 'Done',
        subtitle: '$dailyCount/$dailyLimit',
        color: isLight ? Colors.blueGrey.shade700 : Colors.blueGrey,
        icon: Icons.check_circle,
        tooltip:
            'Daily Trade Limit Reached\nTrades Today: $dailyCount/$dailyLimit',
      );
    } else if (isAutoTrading) {
      return _StatusAttributes(
        title: 'Trading',
        subtitle: '$dailyCount/$dailyLimit',
        color: isLight ? Colors.green.shade700 : Colors.green,
        icon: Icons.play_circle,
        tooltip: 'Auto-Trading Active\nTrades Today: $dailyCount/$dailyLimit',
      );
    } else {
      final minutes = countdownSeconds ~/ 60;
      final seconds = countdownSeconds % 60;
      final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

      return _StatusAttributes(
        title: 'Auto On',
        subtitle: timeStr,
        color: isLight ? Colors.amber.shade800 : Colors.amber,
        icon: Icons.schedule,
        tooltip:
            'Auto-Trade Enabled\nNext Check: $timeStr\nTrades Today: $dailyCount/$dailyLimit',
      );
    }
  }
}

class _StatusAttributes {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final String tooltip;

  _StatusAttributes({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.tooltip,
  });
}
