import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/portfolio_privacy_settings.dart';
import 'package:robinhood_options_mobile/model/top_portfolio_entry.dart';
import 'package:robinhood_options_mobile/model/verified_track_record.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

/// Modal bottom sheet allowing users to publish, update, or unpublish their
/// portfolio from the Top Portfolios Leaderboard, as well as configure privacy settings.
class PublishPortfolioBottomSheet extends StatefulWidget {
  final firebase_auth.FirebaseAuth auth;
  final FirestoreService firestoreService;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final VoidCallback? onPublished;
  final VoidCallback? onUnpublished;

  const PublishPortfolioBottomSheet({
    super.key,
    required this.auth,
    required this.firestoreService,
    this.brokerageUser,
    this.service,
    this.onPublished,
    this.onUnpublished,
  });

  static Future<void> show(
    BuildContext context, {
    required firebase_auth.FirebaseAuth auth,
    required FirestoreService firestoreService,
    BrokerageUser? brokerageUser,
    IBrokerageService? service,
    VoidCallback? onPublished,
    VoidCallback? onUnpublished,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PublishPortfolioBottomSheet(
        auth: auth,
        firestoreService: firestoreService,
        brokerageUser: brokerageUser,
        service: service,
        onPublished: onPublished,
        onUnpublished: onUnpublished,
      ),
    );
  }

  @override
  State<PublishPortfolioBottomSheet> createState() =>
      _PublishPortfolioBottomSheetState();
}

class _PublishPortfolioBottomSheetState
    extends State<PublishPortfolioBottomSheet> {
  bool _isLoading = true;
  bool _isSaving = false;

  TopPortfolioEntry? _existingEntry;
  VerifiedTrackRecord? _verifiedRecord;
  String? _userName;
  String? _userPhotoUrl;
  String? _location;
  int _followersCount = 0;
  int _followingCount = 0;

  // Privacy toggles
  bool _isPublic = true;
  bool _showHoldings = false;
  bool _showTrades = true;
  bool _showTradeAmounts = false;
  bool _allowFollowers = true;

  final NumberFormat _percentFormat =
      NumberFormat.decimalPercentPattern(decimalDigits: 1);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final currentUserId = widget.auth.currentUser?.uid;
    if (currentUserId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final userDoc =
          await widget.firestoreService.userCollection.doc(currentUserId).get();
      final existingTop =
          await widget.firestoreService.getTopPortfolioEntry(currentUserId);
      final verified =
          await widget.firestoreService.getVerifiedTrackRecord(currentUserId);

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        _userName = userData.name;
        _userPhotoUrl = userData.photoUrl;
        _location = userData.location;
        _followersCount = userData.followersCount;
        _followingCount = userData.followingCount;

        final privacy =
            userData.portfolioPrivacy ?? const PortfolioPrivacySettings();
        _isPublic = privacy.isPublic;
        _showHoldings = privacy.showHoldings;
        _showTrades = privacy.showTrades;
        _showTradeAmounts = privacy.showTradeAmounts;
        _allowFollowers = privacy.allowFollowers;
      }

      _userName ??= widget.auth.currentUser?.displayName ??
          widget.brokerageUser?.userName ??
          'Trader';
      _userPhotoUrl ??= widget.auth.currentUser?.photoURL;

      _existingEntry = existingTop;
      _verifiedRecord = verified;
    } catch (e) {
      debugPrint('Error loading user portfolio data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _publishPortfolio() async {
    final currentUserId = widget.auth.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() => _isSaving = true);
    try {
      // 1. Ensure portfolio privacy is set to public so it can be seen
      final privacySettings = PortfolioPrivacySettings(
        isPublic: true,
        showHoldings: _showHoldings,
        showTrades: _showTrades,
        showTradeAmounts: _showTradeAmounts,
        allowFollowers: _allowFollowers,
      );
      await widget.firestoreService
          .updateUserPortfolioPrivacy(currentUserId, privacySettings);
      setState(() => _isPublic = true);

      // 2. Determine metrics
      double returnPercent = 0.0;
      double winRate = 0.0;
      int totalTrades = 0;
      int winningTrades = 0;
      int losingTrades = 0;
      double sharpeRatio = 0.0;
      double maxDrawdownPercent = 0.0;
      double profitFactor = 0.0;
      Map<String, double> periodReturns = {};

      if (_verifiedRecord != null) {
        returnPercent = _verifiedRecord!.verifiedReturnPercent;
        winRate = _verifiedRecord!.verifiedWinRate;
        totalTrades = _verifiedRecord!.totalTradesAudited;
        winningTrades = _verifiedRecord!.winningTrades;
        losingTrades = _verifiedRecord!.losingTrades;
        sharpeRatio = _verifiedRecord!.sharpeRatio;
        maxDrawdownPercent = _verifiedRecord!.maxDrawdownPercent;
        profitFactor = _verifiedRecord!.profitFactor;
        periodReturns = _verifiedRecord!.monthlyReturns;
      } else if (_existingEntry != null) {
        returnPercent = _existingEntry!.returnPercent;
        winRate = _existingEntry!.winRate;
        totalTrades = _existingEntry!.totalTrades;
        winningTrades = _existingEntry!.winningTrades;
        losingTrades = _existingEntry!.losingTrades;
        sharpeRatio = _existingEntry!.sharpeRatio;
        maxDrawdownPercent = _existingEntry!.maxDrawdownPercent;
        profitFactor = _existingEntry!.profitFactor;
        periodReturns = _existingEntry!.periodReturns;
      } else {
        // Fallback / initial estimates based on account data if present
        periodReturns = {
          '1W': returnPercent * 0.15,
          '1M': returnPercent * 0.35,
          '3M': returnPercent * 0.65,
          '1Y': returnPercent,
          'ALL': returnPercent,
        };
      }

      final reputation = UserReputation.calculate(
        trackRecord: _verifiedRecord,
        returnPercent: returnPercent,
        winRate: winRate,
        totalTrades: totalTrades,
        followersCount: _followersCount,
      );

      final entry = TopPortfolioEntry(
        userId: currentUserId,
        userName: _userName ?? 'Trader',
        userPhotoUrl: _userPhotoUrl,
        location: _location,
        followersCount: _followersCount,
        followingCount: _followingCount,
        isPublic: true,
        returnPercent: returnPercent,
        winRate: winRate,
        totalTrades: totalTrades,
        winningTrades: winningTrades,
        losingTrades: losingTrades,
        sharpeRatio: sharpeRatio,
        maxDrawdownPercent: maxDrawdownPercent,
        profitFactor: profitFactor,
        periodReturns: periodReturns,
        verifiedTrackRecord: _verifiedRecord,
        reputation: reputation,
      );

      await widget.firestoreService.setTopPortfolioEntry(entry);

      if (mounted) {
        setState(() {
          _existingEntry = entry;
        });
        widget.onPublished?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Portfolio successfully published to Leaderboard!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish portfolio: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _unpublishPortfolio() async {
    final currentUserId = widget.auth.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() => _isSaving = true);
    try {
      await widget.firestoreService.deleteTopPortfolioEntry(currentUserId);

      if (mounted) {
        setState(() {
          _existingEntry = null;
        });
        widget.onUnpublished?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Portfolio unpublished from Leaderboard.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unpublish portfolio: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updatePrivacyOnly() async {
    final currentUserId = widget.auth.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() => _isSaving = true);
    try {
      final updated = PortfolioPrivacySettings(
        isPublic: _isPublic,
        showHoldings: _showHoldings,
        showTrades: _showTrades,
        showTradeAmounts: _showTradeAmounts,
        allowFollowers: _allowFollowers,
      );
      await widget.firestoreService
          .updateUserPortfolioPrivacy(currentUserId, updated);

      // If user had a published entry, also sync the isPublic flag
      if (_existingEntry != null) {
        final syncedEntry = _existingEntry!.copyWith(isPublic: _isPublic);
        await widget.firestoreService.setTopPortfolioEntry(syncedEntry);
        setState(() => _existingEntry = syncedEntry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings updated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update privacy settings: $e'),
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
    final user = widget.auth.currentUser;

    if (user == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Icon(Icons.account_circle_outlined,
                size: 56, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Sign In Required',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please sign in to publish your portfolio and appear on the Top Portfolios Leaderboard.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isPublished = _existingEntry != null;

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
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.publish_rounded,
                        color: colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leaderboard Publication',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Manage your public visibility and ranking',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Status Card
              Card(
                elevation: 0,
                color: isPublished
                    ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isPublished
                        ? colorScheme.primary.withValues(alpha: 0.4)
                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPublished
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isPublished
                                ? Colors.green
                                : colorScheme.outline,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isPublished
                                ? 'Status: Published'
                                : 'Status: Not Published',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPublished
                                  ? Colors.green
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          if (_verifiedRecord?.isVerified == true)
                            Chip(
                              avatar: const Icon(Icons.verified,
                                  size: 14, color: Colors.blue),
                              label: const Text('Verified',
                                  style: TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPublished
                            ? 'Your portfolio is active on the leaderboard. Other traders can view your performance and reputation tier.'
                            : 'Publish your portfolio to showcase your track record, earn reputation points, and attract followers.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isPublished && !_isPublic) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: colorScheme.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your portfolio privacy is currently Private. Turn on "Public Portfolio" below so it is visible on the leaderboard.',
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (isPublished) ...[
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              context,
                              'Return',
                              '${_existingEntry!.returnPercent >= 0 ? '+' : ''}${_percentFormat.format(_existingEntry!.returnPercent / 100)}',
                              _existingEntry!.returnPercent >= 0
                                  ? Colors.green
                                  : colorScheme.error,
                            ),
                            _buildStatItem(
                              context,
                              'Win Rate',
                              '${_existingEntry!.winRate.toStringAsFixed(1)}%',
                              colorScheme.primary,
                            ),
                            _buildStatItem(
                              context,
                              'Trades',
                              '${_existingEntry!.totalTrades}',
                              colorScheme.onSurface,
                            ),
                            _buildStatItem(
                              context,
                              'Reputation',
                              '${_existingEntry!.reputation.score} pts',
                              colorScheme.tertiary,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Privacy Controls Header
              Text(
                'Portfolio & Social Privacy',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Card(
                elevation: 0,
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: _isPublic,
                      title: const Text('Public Portfolio'),
                      subtitle: Text(
                        _isPublic
                            ? 'Visible on leaderboard & trader profile'
                            : 'Hidden from public leaderboard & profile',
                        style: TextStyle(
                          color: _isPublic
                              ? colorScheme.primary
                              : colorScheme.outline,
                        ),
                      ),
                      secondary: Icon(
                        _isPublic ? Icons.public : Icons.public_off,
                        color: _isPublic
                            ? colorScheme.primary
                            : theme.disabledColor,
                      ),
                      onChanged: (val) {
                        setState(() => _isPublic = val);
                        _updatePrivacyOnly();
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      value: _allowFollowers,
                      title: const Text('Allow Followers'),
                      subtitle: const Text('Let other traders follow you'),
                      secondary: const Icon(Icons.person_add_alt_1_outlined),
                      onChanged: (val) {
                        setState(() => _allowFollowers = val);
                        _updatePrivacyOnly();
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      value: _showHoldings,
                      title: const Text('Show Open Holdings'),
                      subtitle: const Text('Display your active positions'),
                      secondary: const Icon(Icons.pie_chart_outline),
                      onChanged: (val) {
                        setState(() => _showHoldings = val);
                        _updatePrivacyOnly();
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      value: _showTradeAmounts,
                      title: const Text('Show Exact Dollar Amounts'),
                      subtitle: Text(
                        _showTradeAmounts
                            ? 'Exact dollar amounts visible'
                            : 'Values masked (\$***)',
                      ),
                      secondary: const Icon(Icons.attach_money),
                      onChanged: (val) {
                        setState(() => _showTradeAmounts = val);
                        _updatePrivacyOnly();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              if (!isPublished) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _publishPortfolio,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.publish),
                    label: Text(_isSaving
                        ? 'Publishing...'
                        : 'Publish Portfolio to Leaderboard'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _publishPortfolio,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync, size: 18),
                        label: const Text('Update Stats'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _unpublishPortfolio,
                        icon: const Icon(Icons.visibility_off, size: 18),
                        label: const Text('Unpublish'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(
                              color: colorScheme.error.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
