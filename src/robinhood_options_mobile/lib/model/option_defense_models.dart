import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_roll_models.dart';

/// Threat level indicating how severely an option position or short leg is tested.
enum OptionDefenseThreatLevel {
  /// Unthreatened: far out-of-the-money, low delta, comfortable DTE.
  safe,

  /// Approaching short strike, elevated delta (> 0.35), or DTE < 14 with rising gamma.
  caution,

  /// Short strike has been breached (ITM), or delta > 0.50. Action is strongly recommended.
  breached,

  /// Deep in-the-money (> 3% breach) or DTE < 3 with strike breached. Urgent defense required.
  critical,
}

/// Threat assessment diagnostic for an option position.
class OptionDefenseThreat {
  final OptionDefenseThreatLevel level;
  final bool isTested;
  final double? distanceToStrike; // Spot to strike % difference (e.g. +2.5% or -1.8%)
  final double? shortStrike;
  final double? underlyingPrice;
  final int daysToExpiration;
  final double? delta;
  final List<String> threatReasons;
  final String statusTitle;
  final String statusDescription;

  const OptionDefenseThreat({
    required this.level,
    required this.isTested,
    this.distanceToStrike,
    this.shortStrike,
    this.underlyingPrice,
    required this.daysToExpiration,
    this.delta,
    required this.threatReasons,
    required this.statusTitle,
    required this.statusDescription,
  });
}

/// Type of defensive tactical adjustment recommended by the playbook.
enum DefenseActionType {
  /// Roll expiration out in time at the same strike to collect extrinsic credit and extend duration.
  rollOutTime,

  /// Roll strike away from spot and out in time (Roll Up & Out for Calls, Roll Down & Out for Puts).
  rollStrikeAway,

  /// Convert a tested single spread into an Iron Condor by selling an opposing credit spread on the untested side.
  convertIronCondor,

  /// Invert short strikes or rebalance legs for severe breaches.
  invertStrangle,

  /// Cut losses / close the position to preserve capital when rolling for credit is unviable.
  closePosition,

  /// Hold position or take profit when threat is low.
  holdOrTakeProfit,
}

/// A specific defensive playbook action recommended to the trader.
class DefensePlaybookAction {
  final DefenseActionType actionType;
  final String title;
  final String badge;
  final String objective;
  final String rationale;
  final RollPreset? suggestedPreset;
  final OptionDefenseThreatLevel urgency;
  final String expectedImpact;
  final List<String> executionSteps;
  final bool isRecommended;

  const DefensePlaybookAction({
    required this.actionType,
    required this.title,
    required this.badge,
    required this.objective,
    required this.rationale,
    this.suggestedPreset,
    required this.urgency,
    required this.expectedImpact,
    required this.executionSteps,
    this.isRecommended = false,
  });
}

/// The complete defense playbook analyzing a position and generating tactical adjustments.
class OptionDefensePlaybook {
  final OptionAggregatePosition position;
  final OptionInstrument optionInstrument;
  final double? underlyingPrice;
  final double? underlyingCostBasis;
  final OptionDefenseThreat threat;
  final List<DefensePlaybookAction> actions;

  const OptionDefensePlaybook._({
    required this.position,
    required this.optionInstrument,
    this.underlyingPrice,
    this.underlyingCostBasis,
    required this.threat,
    required this.actions,
  });

  /// Evaluates the position and underlying market data to generate a complete defense playbook.
  factory OptionDefensePlaybook.analyze({
    required OptionAggregatePosition position,
    required OptionInstrument optionInstrument,
    double? underlyingPrice,
    double? underlyingCostBasis,
  }) {
    // 1. Determine if position is short or long
    final isShort = position.direction == 'credit' ||
        (position.legs.isNotEmpty &&
            position.legs.first.positionType == 'short');

    final isCall = optionInstrument.type.toLowerCase() == 'call';
    final strike = optionInstrument.strikePrice ?? 0.0;
    final spot = underlyingPrice ??
        position.instrumentObj?.quoteObj?.lastTradePrice ??
        strike;

    // Days to expiration
    final now = DateTime.now();
    final dte = optionInstrument.expirationDate != null
        ? optionInstrument.expirationDate!.difference(now).inDays
        : 0;

    // Delta
    final delta = optionInstrument.optionMarketData?.delta;
    final absDelta = delta?.abs();

    // Distance to strike calculation (percentage from spot to strike)
    double? distPct;
    if (spot > 0 && strike > 0) {
      distPct = ((spot - strike) / strike) * 100.0;
    }

    // Is the short strike breached?
    // For Short Call: breached if spot > strike
    // For Short Put: breached if spot < strike
    final bool isBreached = isCall ? (spot >= strike) : (spot <= strike);
    final double breachMargin = isCall ? (spot - strike) : (strike - spot);
    final double breachPct = strike > 0 ? (breachMargin / strike) * 100.0 : 0.0;

    // Determine threat level & reasons
    final List<String> reasons = [];
    OptionDefenseThreatLevel level = OptionDefenseThreatLevel.safe;

    if (isShort) {
      if (isBreached) {
        if (breachPct > 3.0 || (dte <= 3 && breachPct > 0)) {
          level = OptionDefenseThreatLevel.critical;
          reasons.add(
              'Strike breached by ${breachPct.toStringAsFixed(1)}% (Spot \$${spot.toStringAsFixed(2)} vs Strike \$${strike.toStringAsFixed(2)}).');
          if (dte <= 3) {
            reasons.add(
                'Critical DTE expiration pressure: only $dte day${dte == 1 ? '' : 's'} remaining.');
          }
        } else {
          level = OptionDefenseThreatLevel.breached;
          reasons.add(
              'Underlying price is in-the-money (${isCall ? 'above' : 'below'} short strike by \$${breachMargin.toStringAsFixed(2)}).');
        }
      } else {
        // Not yet breached, evaluate proximity and delta
        final double distToStrikePct = breachPct.abs();
        final bool isClose = distToStrikePct <= 2.5;
        final bool highDelta = absDelta != null && absDelta >= 0.35;
        final bool gammaRisk = dte <= 14 && (isClose || highDelta);

        if (isClose || highDelta || gammaRisk) {
          level = OptionDefenseThreatLevel.caution;
          if (isClose) {
            reasons.add(
                'Spot is within ${distToStrikePct.toStringAsFixed(1)}% of short strike (\$${strike.toStringAsFixed(2)}).');
          }
          if (highDelta) {
            reasons.add(
                'Delta magnitude (${absDelta.toStringAsFixed(2)}) indicates an elevated ${(absDelta * 100).toStringAsFixed(0)}% probability of expiring ITM.');
          }
          if (gammaRisk) {
            reasons.add(
                'Gamma risk accelerates within $dte DTE, making spot moves amplify losses quickly.');
          }
        } else {
          level = OptionDefenseThreatLevel.safe;
          reasons.add(
              'Position is comfortable with ${distToStrikePct.toStringAsFixed(1)}% buffer to short strike.');
          if (dte > 14) {
            reasons.add('$dte DTE provides ample time for theta decay.');
          }
        }
      }
    } else {
      // Long position threat analysis
      if (dte <= 7 && (absDelta != null && absDelta < 0.25)) {
        level = OptionDefenseThreatLevel.caution;
        reasons.add(
            'Extrinsic theta decay is accelerating with $dte DTE and low delta.');
      } else {
        level = OptionDefenseThreatLevel.safe;
        reasons.add('Long contract with manageable theta profile.');
      }
    }

    final isTested = level != OptionDefenseThreatLevel.safe;

    String statusTitle;
    String statusDesc;
    switch (level) {
      case OptionDefenseThreatLevel.critical:
        statusTitle = 'CRITICAL: Strike Heavily Breached';
        statusDesc =
            'Short leg is deep ITM with imminent assignment or high gamma risk. Urgent defense or capital preservation recommended.';
        break;
      case OptionDefenseThreatLevel.breached:
        statusTitle = 'TESTED: Strike Breached';
        statusDesc =
            'Underlying spot price has crossed your short strike. Deploy tactical adjustments to buy time and lower breakeven.';
        break;
      case OptionDefenseThreatLevel.caution:
        statusTitle = 'CAUTION: Approaching Short Strike';
        statusDesc =
            'Delta is elevating or spot price is pressing toward your short strike. Prepare defensive maneuvers before breach.';
        break;
      case OptionDefenseThreatLevel.safe:
        statusTitle = 'SAFE: Position Intact';
        statusDesc =
            'Position is functioning within expected parameters. Let theta decay work or consider taking profit at target.';
        break;
    }

    final threat = OptionDefenseThreat(
      level: level,
      isTested: isTested,
      distanceToStrike: distPct,
      shortStrike: strike,
      underlyingPrice: spot,
      daysToExpiration: dte,
      delta: delta,
      threatReasons: reasons,
      statusTitle: statusTitle,
      statusDescription: statusDesc,
    );

    // 2. Build tactical playbook recommendations based on strategy and threat
    final List<DefensePlaybookAction> actions = [];
    final strategy = (position.strategy.isNotEmpty
            ? position.strategy
            : (position.direction == 'credit' ? 'Credit Spread' : 'Option'))
        .toLowerCase();
    final bool isSpread = strategy.contains('spread') || position.legs.length > 1;

    if (level == OptionDefenseThreatLevel.critical) {
      // Critical Defense
      actions.add(DefensePlaybookAction(
        actionType: DefenseActionType.rollOutTime,
        title: 'Roll Out in Time (Same Strike)',
        badge: 'TIME DEFENSE',
        objective: 'Extend expiration to collect additional extrinsic credit.',
        rationale:
            'When heavily tested, rolling the same strike out 30-45 days harvests more extrinsic value to cushion losses and gives the underlying room to revert.',
        suggestedPreset: RollPreset.rollOut,
        urgency: OptionDefenseThreatLevel.critical,
        expectedImpact: '+Net Credit expected to lower breakeven',
        executionSteps: [
          'Buy to close the current short leg at mark/ask.',
          'Sell to open a replacement contract 30-45 days out at the same strike.',
          'Ensure the transaction generates a net credit.',
        ],
        isRecommended: true,
      ));

      if (isCall) {
        actions.add(DefensePlaybookAction(
          actionType: DefenseActionType.rollStrikeAway,
          title: 'Roll Up & Out (+Strike & Time)',
          badge: 'STRIKE DEFENSE',
          objective: 'Roll strike higher and further out in time.',
          rationale:
            'Moves the strike price closer to or above spot price to lower assignment risk, while using later expiration to finance the move.',
          suggestedPreset: RollPreset.rollUpAndOut,
          urgency: OptionDefenseThreatLevel.critical,
          expectedImpact: 'Delta reduction with even or small credit',
          executionSteps: [
            'Buy to close current breached call.',
            'Sell to open a higher strike call at an expiration 45-60 days out.',
            'Verify that the net trade achieves at least flat or positive credit.',
          ],
        ));
      } else {
        actions.add(DefensePlaybookAction(
          actionType: DefenseActionType.rollStrikeAway,
          title: 'Roll Down & Out (-Strike & Time)',
          badge: 'STRIKE DEFENSE',
          objective: 'Roll strike lower and further out in time.',
          rationale:
            'Lowers the put strike closer to current spot to reduce delta and lower cash assignment obligation.',
          suggestedPreset: RollPreset.rollDownAndOut,
          urgency: OptionDefenseThreatLevel.critical,
          expectedImpact: 'Lowers breakeven and cash commitment',
          executionSteps: [
            'Buy to close current breached put.',
            'Sell to open a lower strike put at an expiration 45-60 days out.',
            'Ensure the roll is executed for a net credit or flat.',
          ],
        ));
      }

      actions.add(const DefensePlaybookAction(
        actionType: DefenseActionType.closePosition,
        title: 'Close Position & Preserve Capital',
        badge: 'RISK CONTROL',
        objective: 'Cut losses to prevent further tail-risk expansion.',
        rationale:
            'If the underlying fundamentals have shifted or rolling for a net credit is mathematically impossible, closing the trade halts further capital destruction.',
        suggestedPreset: null,
        urgency: OptionDefenseThreatLevel.critical,
        expectedImpact: 'Defines max loss and frees up margin',
        executionSteps: [
          'Submit a closing market or limit order for the position.',
          'Reallocate freed buying power to higher-probability setups.',
        ],
      ));
    } else if (level == OptionDefenseThreatLevel.breached) {
      // Breached Defense: Offer both Roll Strike Away and Roll Out in Time
      final bool recommendRollAway = breachPct <= 2.0;

      actions.add(DefensePlaybookAction(
        actionType: DefenseActionType.rollStrikeAway,
        title: isCall ? 'Roll Up & Out' : 'Roll Down & Out',
        badge: recommendRollAway ? 'RECOMMENDED' : 'ALTERNATIVE',
        objective: isCall
            ? 'Roll to a higher strike on a later expiration date.'
            : 'Roll to a lower strike on a later expiration date.',
        rationale:
            'Reduces directional delta exposure and moves the short strike away from the current spot price while extending duration.',
        suggestedPreset:
            isCall ? RollPreset.rollUpAndOut : RollPreset.rollDownAndOut,
        urgency: OptionDefenseThreatLevel.breached,
        expectedImpact: 'Lowers delta, expands OTM buffer',
        executionSteps: [
          'Select an expiration 21-45 days further out.',
          'Select a strike 1-2 strikes further OTM.',
          'Confirm the roll achieves a net credit.',
        ],
        isRecommended: recommendRollAway,
      ));

      actions.add(DefensePlaybookAction(
        actionType: DefenseActionType.rollOutTime,
        title: 'Roll Out in Time (Same Strike)',
        badge: !recommendRollAway ? 'RECOMMENDED' : 'ALTERNATIVE',
        objective: 'Extend expiration date while keeping the exact same strike.',
        rationale:
            'Collects additional extrinsic credit without taking a strike concession, effectively lowering the trade breakeven.',
        suggestedPreset: RollPreset.rollOut,
        urgency: OptionDefenseThreatLevel.breached,
        expectedImpact: '+Net Credit received, DTE extended',
        executionSteps: [
          'Select the next standard monthly expiration (30-45 DTE).',
          'Keep the existing strike price.',
          'Execute order via Roll Assistant.',
        ],
        isRecommended: !recommendRollAway,
      ));

      if (isSpread || strategy.contains('put') || strategy.contains('call')) {
        actions.add(const DefensePlaybookAction(
          actionType: DefenseActionType.convertIronCondor,
          title: 'Convert to Iron Condor',
          badge: 'ZERO MARGIN CREDIT',
          objective:
              'Sell an opposing credit spread on the untested side of the market.',
          rationale:
              'Because margin is only held on the wider of the two sides, selling the opposing spread collects instant credit to offset losses without increasing capital requirement.',
          suggestedPreset: null,
          urgency: OptionDefenseThreatLevel.breached,
          expectedImpact: '+Net Credit collected with zero additional margin',
          executionSteps: [
            'Identify the untested side (e.g. Call spread if Put spread is tested).',
            'Sell an out-of-the-money credit spread with matching expiration.',
            'Credit collected directly cushions the tested side loss.',
          ],
        ));
      }
    } else if (level == OptionDefenseThreatLevel.caution) {
      // Caution: Early tactical adjustment
      actions.add(DefensePlaybookAction(
        actionType: DefenseActionType.rollOutTime,
        title: 'Roll Out in Time',
        badge: 'RECOMMENDED',
        objective: 'Roll to a 30-45 DTE cycle to reset gamma risk.',
        rationale:
            'Rolling before an actual strike breach allows you to capture maximum extrinsic credit while delta is still manageable.',
        suggestedPreset: RollPreset.rollOut,
        urgency: OptionDefenseThreatLevel.caution,
        expectedImpact: 'Maximizes net credit capture before breach',
        executionSteps: [
          'Select the next 30-45 DTE monthly expiration.',
          'Maintain or slightly widen the strike.',
          'Lock in credit before gamma accelerates inside 14 DTE.',
        ],
        isRecommended: true,
      ));

      actions.add(DefensePlaybookAction(
        actionType: DefenseActionType.rollStrikeAway,
        title: isCall ? 'Roll Up & Out' : 'Roll Down & Out',
        badge: 'PROACTIVE DEFENSE',
        objective: 'Move strike further away while keeping net credit positive.',
        rationale:
            'Proactively widening the distance to spot prevents the underlying from breaching your short strike.',
        suggestedPreset:
            isCall ? RollPreset.rollUpAndOut : RollPreset.rollDownAndOut,
        urgency: OptionDefenseThreatLevel.caution,
        expectedImpact: 'Reduces delta from ${absDelta?.toStringAsFixed(2) ?? "current"} to ~0.20',
        executionSteps: [
          'Roll out 30-45 days.',
          'Adjust strike 1 strike further OTM.',
          'Ensure the net order is for a credit.',
        ],
      ));
    } else {
      // Safe: Monitor or take profit
      actions.add(const DefensePlaybookAction(
        actionType: DefenseActionType.holdOrTakeProfit,
        title: 'Hold Position / Manage at 50% Profit',
        badge: 'ON TRACK',
        objective: 'Let theta time decay work according to plan.',
        rationale:
            'The position is comfortably out-of-the-money with favorable Greeks. Close early if 50% of max profit has been captured.',
        suggestedPreset: null,
        urgency: OptionDefenseThreatLevel.safe,
        expectedImpact: 'Capture remaining theta decay',
        executionSteps: [
          'No defensive action required.',
          'Set a Good-’Til-Cancelled limit order to buy back at 50% of initial credit.',
        ],
        isRecommended: true,
      ));
    }

    return OptionDefensePlaybook._(
      position: position,
      optionInstrument: optionInstrument,
      underlyingPrice: spot,
      underlyingCostBasis: underlyingCostBasis,
      threat: threat,
      actions: actions,
    );
  }
}
