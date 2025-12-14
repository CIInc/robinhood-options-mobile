import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';
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
class AutoTradeStatusBadgeWidget extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;

  const AutoTradeStatusBadgeWidget({
    super.key,
    this.user,
    this.userDocRef,
  });

  @override
  State<AutoTradeStatusBadgeWidget> createState() =>
      _AutoTradeStatusBadgeWidgetState();
}

class _AutoTradeStatusBadgeWidgetState extends State<AutoTradeStatusBadgeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AgenticTradingProvider>(
      builder: (context, agenticTradingProvider, child) {
        final isAutoTrading = agenticTradingProvider.showAutoTradingVisual;

        if (agenticTradingProvider.config['autoTradeEnabled'] as bool? ??
            false) {
          final isActive = isAutoTrading;

          // Trigger animation when state changes
          if (isActive && !_wasActive) {
            _animationController.repeat(reverse: true);
            HapticFeedback.mediumImpact();
            _wasActive = true;
          } else if (!isActive && _wasActive) {
            _animationController.stop();
            _animationController.reset();
            _wasActive = false;
          }
          final dailyCount = agenticTradingProvider.dailyTradeCount;
          final dailyLimit =
              agenticTradingProvider.config['dailyTradeLimit'] as int? ?? 5;
          final emergencyStop = agenticTradingProvider.emergencyStopActivated;
          final countdownSeconds =
              agenticTradingProvider.autoTradeCountdownSeconds;

          String statusText = '';
          Color statusColor = Colors.amber;
          IconData statusIcon = Icons.schedule;
          String displayText = 'Auto';
          String secondLine = '';

          if (emergencyStop) {
            statusText = 'Emergency Stop';
            statusColor = Colors.red;
            statusIcon = Icons.stop_circle;
            secondLine = 'STOP';
          } else if (isActive) {
            statusText = 'Trading...';
            statusColor = Colors.green;
            statusIcon = Icons.play_circle;
            secondLine = '$dailyCount/$dailyLimit';
          } else {
            statusText = 'Auto Enabled';
            statusColor = Colors.amber;
            statusIcon = Icons.schedule;
            final minutes = countdownSeconds ~/ 60;
            final seconds = countdownSeconds % 60;
            secondLine = '$minutes:${seconds.toString().padLeft(2, '0')}';
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Tooltip(
              message:
                  '$statusText\nTrades Today: $dailyCount/$dailyLimit\nNext Trade: $secondLine\nClick to open settings',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (widget.user != null && widget.userDocRef != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AgenticTradingSettingsWidget(
                          user: widget.user!,
                          userDocRef: widget.userDocRef!,
                        ),
                      ),
                    );
                  }
                },
                child: Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor, width: 1.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isActive)
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(statusColor),
                              ),
                            )
                          else
                            Icon(
                              statusIcon,
                              size: 14,
                              color: statusColor,
                            ),
                          const SizedBox(width: 6),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                  height: 1.0,
                                ),
                              ),
                              Text(
                                secondLine,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: statusColor,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
