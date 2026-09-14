import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';

import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
import 'package:robinhood_options_mobile/widgets/day_trade_monitor_widget.dart';
import 'package:robinhood_options_mobile/widgets/margin_health_widget.dart';
import 'package:robinhood_options_mobile/widgets/margin_financing_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_collateral_widget.dart';
import 'package:robinhood_options_mobile/widgets/stock_loan_widget.dart';
import 'package:robinhood_options_mobile/widgets/banking_widget.dart';
import 'package:robinhood_options_mobile/widgets/tax_documents_widget.dart';

final formatDate = DateFormat("yMMMd");
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatNumber = NumberFormat("0.####");
final formatCompactNumber = NumberFormat.compact();

class UserInfoWidget extends StatefulWidget {
  final UserInfo user;
  final BrokerageUser brokerageUser;
  final FirestoreService firestoreService;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;

  const UserInfoWidget({
    super.key,
    required this.user,
    required this.brokerageUser,
    required this.firestoreService,
    this.service,
    this.analytics,
    this.observer,
  });

  @override
  State<UserInfoWidget> createState() => _UserInfoWidgetState();
}

class _UserInfoWidgetState extends State<UserInfoWidget> {
  Timer? _tokenExpirationTimer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTokenExpirationTimer();
  }

  @override
  void didUpdateWidget(covariant UserInfoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brokerageUser != widget.brokerageUser ||
        oldWidget.brokerageUser.oauth2Client?.credentials.expiration !=
            widget.brokerageUser.oauth2Client?.credentials.expiration) {
      _startTokenExpirationTimer();
    }
  }

  @override
  void dispose() {
    _tokenExpirationTimer?.cancel();
    super.dispose();
  }

  void _startTokenExpirationTimer() {
    _tokenExpirationTimer?.cancel();
    final expiration =
        widget.brokerageUser.oauth2Client?.credentials.expiration;
    if (expiration != null) {
      final diff = expiration.difference(DateTime.now());
      final totalSeconds = (diff.inMilliseconds / 1000).ceil();
      _remainingTime =
          totalSeconds > 0 ? Duration(seconds: totalSeconds) : Duration.zero;

      if (_remainingTime > Duration.zero) {
        _tokenExpirationTimer =
            Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          final liveDiff = expiration.difference(DateTime.now());
          final liveSeconds = (liveDiff.inMilliseconds / 1000).ceil();
          if (liveSeconds < _remainingTime.inSeconds && liveSeconds >= 0) {
            _remainingTime = Duration(seconds: liveSeconds);
          } else if (_remainingTime.inSeconds > 0) {
            _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
          } else {
            _remainingTime = Duration.zero;
          }

          setState(() {});
          if (_remainingTime <= Duration.zero) {
            timer.cancel();
          }
        });
      }
    } else {
      _remainingTime = Duration.zero;
    }
  }

  String _formatExpirationDuration(Duration duration) {
    if (duration <= Duration.zero || duration.isNegative) {
      return "Expired";
    }
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return "${hours.toString().padLeft(2, "0")}:${minutes.toString().padLeft(2, "0")}:${seconds.toString().padLeft(2, "0")}";
  }

  String _selectionStorageKey() {
    return AccountStore.selectionStorageKey(
      source: widget.brokerageUser.source.toString(),
      userName: widget.brokerageUser.userName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountStore = Provider.of<AccountStore>(context);
    final activeAccountNum = accountStore.selectedAccountNumber ??
        (widget.brokerageUser.accounts.isNotEmpty
            ? widget.brokerageUser.accounts.first.accountNumber
            : null);

    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        minTileHeight: 10,
        title: const Text("Brokerage", style: TextStyle(fontSize: 14)),
        trailing: Text(
          widget.brokerageUser.source.enumValue().capitalize(),
          style: const TextStyle(fontSize: 16),
        ),
      ),
      if (widget.user.profileName != null) ...[
        ListTile(
          minTileHeight: 10,
          title: const Text("Profile Name", style: TextStyle(fontSize: 14)),
          trailing: Text(
            widget.user.profileName!,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      ListTile(
        minTileHeight: 10,
        title: const Text("Username", style: TextStyle(fontSize: 14)),
        trailing: Text(
          widget.user.username,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (widget.user.lastName != null) ...[
        ListTile(
          minTileHeight: 10,
          title: const Text("Full Name", style: TextStyle(fontSize: 14)),
          trailing: Text("${widget.user.firstName} ${widget.user.lastName}",
              style: const TextStyle(fontSize: 16)),
        ),
      ],
      if (widget.user.email != null) ...[
        ListTile(
          minTileHeight: 10,
          title: const Text("Email", style: TextStyle(fontSize: 14)),
          trailing:
              Text(widget.user.email!, style: const TextStyle(fontSize: 16)),
        ),
      ],
      if (widget.user.createdAt != null) ...[
        ListTile(
          minTileHeight: 10,
          title: const Text("Joined", style: TextStyle(fontSize: 14)),
          trailing: Text(formatDate.format(widget.user.createdAt!),
              style: const TextStyle(fontSize: 16)),
        ),
      ],
      if (widget.user.locality != null) ...[
        ListTile(
          minTileHeight: 10,
          title: const Text("Locality", style: TextStyle(fontSize: 14)),
          trailing:
              Text(widget.user.locality!, style: const TextStyle(fontSize: 16)),
        ),
      ],
      const Divider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              "Accounts",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${widget.brokerageUser.accounts.length}",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Spacer(),
            if (widget.brokerageUser.accounts.length > 1)
              Flexible(
                child: Text(
                  "Tap to switch",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
      if (widget.brokerageUser.accounts.isEmpty) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: Text(
              "No accounts found",
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ),
      ] else ...[
        ...widget.brokerageUser.accounts.map((account) {
          final isSelected = account.accountNumber == activeAccountNum;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: _buildAccountCard(
              context: context,
              account: account,
              isSelected: isSelected,
              showBalances: accountStore.showBalances,
              onSelect: () async {
                HapticFeedback.mediumImpact();
                accountStore.setSelectedAccountNumber(account.accountNumber);
                await accountStore.saveSelectedAccountNumber(
                  _selectionStorageKey(),
                );
                if (context.mounted && Navigator.canPop(context)) {
                  Navigator.pop(context, 'account_switched');
                }
              },
            ),
          );
        }),
      ],
      const SizedBox(height: 8),
      const Divider(),
      if (widget.brokerageUser.oauth2Client != null &&
          widget.brokerageUser.oauth2Client!.credentials.expiration !=
              null) ...[
        ListTile(
          minTileHeight: 10,
          title:
              const Text("Authorization token", style: TextStyle(fontSize: 14)),
          trailing: Text(
            _formatExpirationDuration(_remainingTime),
            style: const TextStyle(fontSize: 16),
          ),
          onLongPress: () async {
            await refreshToken(context, widget.brokerageUser);
          },
        ),
      ],
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          overflowSpacing: 4,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.sync_lock_rounded),
              onPressed: () {
                reauthenticate(context);
              },
              label: const Text('Renew'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await refreshToken(context, widget.brokerageUser);
              },
              label: const Text('Refresh'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.link_off),
              onPressed: () async {
                var userStore =
                    Provider.of<BrokerageUserStore>(context, listen: false);
                userStore.remove(widget.brokerageUser);
                await userStore.save();
                userStore.setCurrentUserIndex(0);

                if (auth.currentUser != null) {
                  final authUtil = AuthUtil(auth);
                  await authUtil.setUser(widget.firestoreService,
                      brokerageUserStore: userStore);
                }
              },
              label: const Text('Unlink'),
            ),
          ],
        ),
      ),
    ]);
  }

  void reauthenticate(BuildContext context) {
    final authUtil = AuthUtil(auth);
    final analytics = widget.analytics ?? MyApp.analytics;
    final observer = widget.observer ?? MyApp.observer;
    authUtil.openLogin(
      context,
      widget.firestoreService,
      analytics,
      observer,
      initialSource: widget.brokerageUser.source,
      initialUserName: widget.brokerageUser.userName,
    );
  }

  Widget _buildAccountCard({
    required BuildContext context,
    required Account account,
    required bool isSelected,
    required bool showBalances,
    required VoidCallback onSelect,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMarginBorrowed = (account.settledAmountBorrowed ?? 0) > 0;
    final isPdtFlagged = account.markedPatternDayTraderDate != null;

    final cardBorderColor = isSelected
        ? colorScheme.primary
        : colorScheme.outlineVariant.withValues(alpha: 0.6);

    final cardBgColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.18)
        : colorScheme.surfaceContainerLow;

    return Material(
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cardBorderColor,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Leading icon, Account number & badges, Active status
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: account.isAgentic
                          ? Colors.amber.withValues(alpha: 0.15)
                          : (isSelected
                              ? colorScheme.primary.withValues(alpha: 0.15)
                              : colorScheme.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      account.isAgentic
                          ? Icons.auto_awesome
                          : Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: account.isAgentic
                          ? (Colors.amber[800] ?? Colors.amber)
                          : (isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            Text(
                              "Account ${account.accountNumber}",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (account.isAgentic) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color:
                                          Colors.amber.withValues(alpha: 0.5)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome,
                                        size: 10, color: Colors.amber),
                                    SizedBox(width: 2),
                                    Text(
                                      "Agentic",
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.type.capitalize(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check,
                              size: 12, color: colorScheme.onPrimary),
                          const SizedBox(width: 3),
                          Text(
                            "Active",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Icon(
                      Icons.radio_button_unchecked,
                      size: 18,
                      color: colorScheme.outline.withValues(alpha: 0.6),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Balances Row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Buying Power",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 1),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              showBalances
                                  ? formatCurrency.format(account.buyingPower ??
                                      account.portfolioCash ??
                                      0)
                                  : '\$••••••',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (account.portfolioCash != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        height: 24,
                        width: 1,
                        color: colorScheme.outlineVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Cash",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 1),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                showBalances
                                    ? formatCurrency
                                        .format(account.portfolioCash!)
                                    : '\$••••••',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (account.optionLevel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        height: 24,
                        width: 1,
                        color: colorScheme.outlineVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Options",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 1),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _formatOptionLevel(account.optionLevel),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Actionable / Informational Badges Row (PDT & Margin)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildPdtChip(context, account, isPdtFlagged),
                  _buildMarginChip(
                      context, account, isMarginBorrowed, showBalances),
                  _buildMarginFinancingChip(context, account),
                  _buildOptionsUpgradeChip(context, account),
                  _buildStockLoanChip(context, account),
                  _buildBankingChip(context, account),
                  _buildTaxDocumentsChip(context, account),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdtChip(
      BuildContext context, Account account, bool isPdtFlagged) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color badgeColor = isPdtFlagged
        ? Colors.purple
        : (account.dayTradesProtection
            ? Colors.teal
            : colorScheme.onSurfaceVariant);
    final Color badgeBg = isPdtFlagged
        ? Colors.purple.withValues(alpha: 0.12)
        : (account.dayTradesProtection
            ? Colors.teal.withValues(alpha: 0.1)
            : colorScheme.surfaceContainerHighest);
    final Color badgeBorder = isPdtFlagged
        ? Colors.purple.withValues(alpha: 0.4)
        : (account.dayTradesProtection
            ? Colors.teal.withValues(alpha: 0.3)
            : colorScheme.outlineVariant);

    final String label = isPdtFlagged
        ? "PDT Flagged"
        : (account.dayTradesProtection ? "PDT Protected" : "Day Trades");

    final IconData icon = isPdtFlagged
        ? Icons.warning_rounded
        : (account.dayTradesProtection
            ? Icons.shield_outlined
            : Icons.show_chart_rounded);

    return Material(
      color: badgeBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: badgeBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          final effectiveService = widget.service ??
              (widget.brokerageUser.source == BrokerageSource.robinhood
                  ? RobinhoodService()
                  : DemoService());
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DayTradeMonitorWidget(
                brokerageUser: widget.brokerageUser,
                service: effectiveService,
                account: account,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 12,
                color: badgeColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarginChip(BuildContext context, Account account,
      bool isMarginBorrowed, bool showBalances) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color badgeColor = isMarginBorrowed
        ? (Colors.amber[800] ?? Colors.amber)
        : colorScheme.onSurfaceVariant;
    final Color badgeBg = isMarginBorrowed
        ? Colors.amber.withValues(alpha: 0.12)
        : colorScheme.surfaceContainerHighest;
    final Color badgeBorder = isMarginBorrowed
        ? Colors.amber.withValues(alpha: 0.4)
        : colorScheme.outlineVariant;

    final String label = isMarginBorrowed
        ? "Margin: ${showBalances ? formatCurrency.format(account.settledAmountBorrowed) : '\$••••••'}"
        : "Unleveraged";

    final IconData icon =
        isMarginBorrowed ? Icons.speed : Icons.check_circle_outline_rounded;

    return Material(
      color: badgeBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: badgeBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          final effectiveService = widget.service ??
              (widget.brokerageUser.source == BrokerageSource.robinhood
                  ? RobinhoodService()
                  : DemoService());
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MarginHealthWidget(
                brokerageUser: widget.brokerageUser,
                service: effectiveService,
                account: account,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 12,
                color: badgeColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarginFinancingChip(BuildContext context, Account account) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color badgeColor = colorScheme.primary;
    final Color badgeBg = colorScheme.primary.withValues(alpha: 0.1);
    final Color badgeBorder = colorScheme.primary.withValues(alpha: 0.3);

    return Material(
      color: badgeBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: badgeBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          final effectiveService = widget.service ??
              (widget.brokerageUser.source == BrokerageSource.robinhood
                  ? RobinhoodService()
                  : DemoService());
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MarginFinancingWidget(
                brokerageUser: widget.brokerageUser,
                service: effectiveService,
                account: account,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gavel_outlined, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  "Margin Calls",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 12,
                color: badgeColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsUpgradeChip(BuildContext context, Account account) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isL3 = account.optionLevel.toLowerCase().contains('3');
    final Color badgeColor = isL3 ? Colors.green : colorScheme.secondary;
    final Color badgeBg = isL3
        ? Colors.green.withValues(alpha: 0.12)
        : colorScheme.secondary.withValues(alpha: 0.1);
    final Color badgeBorder = isL3
        ? Colors.green.withValues(alpha: 0.3)
        : colorScheme.secondary.withValues(alpha: 0.3);
    final String label =
        isL3 ? 'Options L3 Active' : 'Options & Collateral';
    final IconData icon = isL3 ? Icons.verified : Icons.upgrade_rounded;

    return Material(
      color: badgeBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: badgeBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          final effectiveService = widget.service ??
              (widget.brokerageUser.source == BrokerageSource.robinhood
                  ? RobinhoodService()
                  : DemoService());
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OptionCollateralWidget(
                brokerageUser: widget.brokerageUser,
                service: effectiveService,
                account: account,
                initialTabIndex: isL3 ? 0 : 1,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 12,
                color: badgeColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockLoanChip(BuildContext context, Account account) {
    const Color badgeColor = Colors.green;
    final Color badgeBg = Colors.green.withValues(alpha: 0.12);
    final Color badgeBorder = Colors.green.withValues(alpha: 0.3);

    return Material(
      color: badgeBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: badgeBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          final effectiveService = widget.service ??
              (widget.brokerageUser.source == BrokerageSource.robinhood
                  ? RobinhoodService()
                  : DemoService());
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StockLoanWidget(
                brokerageUser: widget.brokerageUser,
                service: effectiveService,
                account: account,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.currency_exchange, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              const Flexible(
                child: Text(
                  'Stock Lending',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 12,
                color: badgeColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankingChip(BuildContext context, Account account) {
    const Color badgeColor = Colors.indigo;
    final Color badgeBg = Colors.indigo.withValues(alpha: 0.12);
    final Color badgeBorder = Colors.indigo.withValues(alpha: 0.3);

    return Material(
      color: badgeBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: badgeBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          final effectiveService = widget.service ??
              (widget.brokerageUser.source == BrokerageSource.robinhood
                  ? RobinhoodService()
                  : DemoService());
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BankingWidget(
                brokerageUser: widget.brokerageUser,
                service: effectiveService,
                account: account,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              const Flexible(
                child: Text(
                  'Banking & Transfers',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 12,
                color: badgeColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaxDocumentsChip(BuildContext context, Account account) {
    const Color badgeColor = Colors.teal;
    final Color badgeBg = Colors.teal.withValues(alpha: 0.12);
    final Color badgeBorder = Colors.teal.withValues(alpha: 0.3);

    return Material(
      color: badgeBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: badgeBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          final effectiveService = widget.service ??
              (widget.brokerageUser.source == BrokerageSource.robinhood
                  ? RobinhoodService()
                  : DemoService());
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaxDocumentsWidget(
                brokerageUser: widget.brokerageUser,
                service: effectiveService,
                account: account,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              const Flexible(
                child: Text(
                  'Tax Documents',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 12,
                color: badgeColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatOptionLevel(String optionLevel) {
    if (optionLevel.isEmpty) return '';
    var cleaned = optionLevel.trim();
    cleaned = cleaned.replaceAll(
      RegExp(r'^(upgrade_requested[\s_]*)?(options?[\s_]*)?(level[\s_]*)?',
          caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'^(options?[\s_]*)?(level[\s_]*)?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return optionLevel;
    return 'Level $cleaned';
  }

  Future<void> refreshToken(BuildContext context, BrokerageUser user) async {
    try {
      debugPrint(user.oauth2Client!.identifier);
      debugPrint(user.oauth2Client!.secret);
      debugPrint(user.oauth2Client!.credentials.toJson());
      final newClient = await user.oauth2Client!.refreshCredentials();
      user.oauth2Client = newClient;
      if (mounted) {
        _startTokenExpirationTimer();
        setState(() {});
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text("Token refreshed."),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ));
      }
    }
  }
}
