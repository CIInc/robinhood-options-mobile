import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/portfolio_privacy_settings.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

/// Modal bottom sheet allowing users to view and update their portfolio privacy settings.
class PortfolioPrivacyBottomSheet extends StatefulWidget {
  final String userId;
  final PortfolioPrivacySettings currentSettings;
  final FirestoreService firestoreService;
  final ValueChanged<PortfolioPrivacySettings>? onUpdated;

  const PortfolioPrivacyBottomSheet({
    super.key,
    required this.userId,
    required this.currentSettings,
    required this.firestoreService,
    this.onUpdated,
  });

  static Future<PortfolioPrivacySettings?> show(
    BuildContext context, {
    required String userId,
    required PortfolioPrivacySettings currentSettings,
    required FirestoreService firestoreService,
  }) {
    return showModalBottomSheet<PortfolioPrivacySettings>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PortfolioPrivacyBottomSheet(
        userId: userId,
        currentSettings: currentSettings,
        firestoreService: firestoreService,
      ),
    );
  }

  @override
  State<PortfolioPrivacyBottomSheet> createState() =>
      _PortfolioPrivacyBottomSheetState();
}

class _PortfolioPrivacyBottomSheetState
    extends State<PortfolioPrivacyBottomSheet> {
  late bool _isPublic;
  late bool _showTradeAmounts;
  late bool _showHoldings;
  late bool _showTrades;
  late bool _allowFollowers;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isPublic = widget.currentSettings.isPublic;
    _showTradeAmounts = widget.currentSettings.showTradeAmounts;
    _showHoldings = widget.currentSettings.showHoldings;
    _showTrades = widget.currentSettings.showTrades;
    _allowFollowers = widget.currentSettings.allowFollowers;
  }

  PortfolioPrivacySettings get _currentDraft => PortfolioPrivacySettings(
        isPublic: _isPublic,
        showTradeAmounts: _showTradeAmounts,
        showHoldings: _showHoldings,
        showTrades: _showTrades,
        allowFollowers: _allowFollowers,
      );

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final updated = _currentDraft;
    try {
      await widget.firestoreService
          .updateUserPortfolioPrivacy(widget.userId, updated);
      widget.onUpdated?.call(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Portfolio privacy settings saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.privacy_tip_outlined,
                      color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Portfolio & Social Privacy',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Control who can see your portfolio and trade activity',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Public Profile Master Toggle
              Card(
                elevation: 0,
                color: _isPublic
                    ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _isPublic
                        ? colorScheme.primary.withValues(alpha: 0.5)
                        : theme.dividerColor,
                  ),
                ),
                child: SwitchListTile.adaptive(
                  value: _isPublic,
                  title: Text(
                    'Public Portfolio',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    _isPublic
                        ? 'Other traders can view your profile and performance'
                        : 'Your profile is private. Other traders cannot see your details',
                  ),
                  secondary: Icon(
                    _isPublic ? Icons.public : Icons.lock_outline,
                    color: _isPublic ? colorScheme.primary : theme.disabledColor,
                  ),
                  onChanged: (val) {
                    setState(() => _isPublic = val);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Granular Controls (only active if isPublic)
              AnimatedOpacity(
                opacity: _isPublic ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_isPublic,
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        value: _allowFollowers,
                        title: const Text('Allow Followers'),
                        subtitle: const Text(
                          'Enable other traders to follow you and your trades',
                        ),
                        secondary: const Icon(Icons.person_add_alt_1_outlined),
                        onChanged: (val) {
                          setState(() => _allowFollowers = val);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: _showHoldings,
                        title: const Text('Show Open Holdings'),
                        subtitle: const Text(
                          'Display your active stock, option, and crypto positions',
                        ),
                        secondary: const Icon(Icons.pie_chart_outline),
                        onChanged: (val) {
                          setState(() => _showHoldings = val);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: _showTrades,
                        title: const Text('Share Trades to Activity Feed'),
                        subtitle: const Text(
                          'Broadcast your executions to your followers and social feed',
                        ),
                        secondary: const Icon(Icons.dynamic_feed_outlined),
                        onChanged: (val) {
                          setState(() => _showTrades = val);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: _showTradeAmounts,
                        title: const Text('Show Dollar Amounts'),
                        subtitle: Text(
                          _showTradeAmounts
                              ? 'Exact trade dollar values and quantities are visible'
                              : 'Dollar values are masked (\$***) for maximum privacy',
                        ),
                        secondary: Icon(
                          _showTradeAmounts
                              ? Icons.attach_money
                              : Icons.money_off,
                        ),
                        onChanged: (val) {
                          setState(() => _showTradeAmounts = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save Preferences'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
