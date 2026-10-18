//
//  PortfolioWidgetLiveActivity.swift
//  PortfolioWidget
//
//  RealizeAlpha - iOS Live Activities & Dynamic Island Widget
//  Real-time option position tracking, P&L status, and 0DTE trailing stop alerts.
//

import ActivityKit
import WidgetKit
import SwiftUI

public struct OptionPositionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentPrice: Double
        public var marketValue: Double
        public var gainLoss: Double
        public var gainLossPercent: Double
        public var changeToday: Double
        public var changePercentToday: Double
        public var peakPrice: Double
        public var trailingStopPrice: Double
        public var trailingStopDistancePercent: Double
        public var isTrailingStopTriggered: Bool
        public var statusText: String
        public var lastUpdatedMillis: Double

        public init(
            currentPrice: Double,
            marketValue: Double,
            gainLoss: Double,
            gainLossPercent: Double,
            changeToday: Double,
            changePercentToday: Double,
            peakPrice: Double,
            trailingStopPrice: Double,
            trailingStopDistancePercent: Double,
            isTrailingStopTriggered: Bool,
            statusText: String,
            lastUpdatedMillis: Double
        ) {
            self.currentPrice = currentPrice
            self.marketValue = marketValue
            self.gainLoss = gainLoss
            self.gainLossPercent = gainLossPercent
            self.changeToday = changeToday
            self.changePercentToday = changePercentToday
            self.peakPrice = peakPrice
            self.trailingStopPrice = trailingStopPrice
            self.trailingStopDistancePercent = trailingStopDistancePercent
            self.isTrailingStopTriggered = isTrailingStopTriggered
            self.statusText = statusText
            self.lastUpdatedMillis = lastUpdatedMillis
        }
    }

    public var positionId: String
    public var symbol: String
    public var strategy: String
    public var strikePrice: Double
    public var expirationDate: String
    public var optionType: String
    public var quantity: Double
    public var direction: String
    public var averageOpenPrice: Double
    public var trailingStopPercent: Double
    public var is0DTE: Bool
    public var dte: Int

    public init(
        positionId: String,
        symbol: String,
        strategy: String,
        strikePrice: Double,
        expirationDate: String,
        optionType: String,
        quantity: Double,
        direction: String,
        averageOpenPrice: Double,
        trailingStopPercent: Double,
        is0DTE: Bool,
        dte: Int
    ) {
        self.positionId = positionId
        self.symbol = symbol
        self.strategy = strategy
        self.strikePrice = strikePrice
        self.expirationDate = expirationDate
        self.optionType = optionType
        self.quantity = quantity
        self.direction = direction
        self.averageOpenPrice = averageOpenPrice
        self.trailingStopPercent = trailingStopPercent
        self.is0DTE = is0DTE
        self.dte = dte
    }
}

struct PortfolioWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OptionPositionAttributes.self) { context in
            // Lock Screen / StandBy / Banner View
            LockScreenLiveActivityView(context: context)
                .widgetURL(URL(string: "realizealpha://position/\(context.attributes.symbol)"))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI regions
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Text(context.attributes.symbol)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        if context.attributes.is0DTE {
                            Text("0DTE")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .foregroundColor(.black)
                                .cornerRadius(4)
                        } else {
                            Text("\(context.attributes.dte)d")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "$%.2f", context.state.currentPrice))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text(String(format: "%@$%.2f (%@%.1f%%)",
                                    context.state.gainLoss >= 0 ? "+" : "",
                                    context.state.gainLoss,
                                    context.state.gainLossPercent >= 0 ? "+" : "",
                                    context.state.gainLossPercent * 100))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(context.state.gainLoss >= 0 ? .green : .red)
                    }
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Trailing stop status meter
                        if context.state.isTrailingStopTriggered {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                                Text("STOP TRIGGERED: Price broke $\(String(format: "%.2f", context.state.trailingStopPrice))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(6)
                        } else {
                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: "shield.checkered")
                                        .font(.system(size: 10))
                                        .foregroundColor(.cyan)
                                    Text("Trail Stop:")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(String(format: "$%.2f (-%.0f%%)", context.state.trailingStopPrice, context.attributes.trailingStopPercent))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                Text(String(format: "%.1f%% away", context.state.trailingStopDistancePercent))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(context.state.trailingStopDistancePercent < 5.0 ? .orange : .secondary)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Text(context.attributes.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    if context.attributes.is0DTE {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                    }
                }
            } compactTrailing: {
                if context.state.isTrailingStopTriggered {
                    Text("STOP")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.red)
                } else {
                    Text(String(format: "%@%.1f%%",
                                context.state.gainLossPercent >= 0 ? "+" : "",
                                context.state.gainLossPercent * 100))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(context.state.gainLossPercent >= 0 ? .green : .red)
                }
            } minimal: {
                if context.state.isTrailingStopTriggered {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                } else {
                    Text(context.attributes.symbol.prefix(3))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(context.state.gainLossPercent >= 0 ? .green : .red)
                }
            }
            .widgetURL(URL(string: "realizealpha://position/\(context.attributes.symbol)"))
            .keylineTint(context.state.isTrailingStopTriggered ? Color.red : Color.blue)
        }
    }
}

// MARK: - Lock Screen & Banner View
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<OptionPositionAttributes>

    var body: some View {
        VStack(spacing: 8) {
            // Header Row
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(context.state.isTrailingStopTriggered ? Color.red : Color.blue)
                        .frame(width: 8, height: 8)
                    Text(context.attributes.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(format: "$%.0f %@", context.attributes.strikePrice, context.attributes.optionType.uppercased()))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                if context.attributes.is0DTE {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                        Text("0DTE")
                            .font(.system(size: 10, weight: .black))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .foregroundColor(.black)
                    .cornerRadius(6)
                } else {
                    Text("Exp \(context.attributes.expirationDate)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // Price & P&L Row
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MARK PRICE")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(0.5)
                    Text(String(format: "$%.2f", context.state.currentPrice))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("TOTAL P&L")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(0.5)
                    HStack(spacing: 4) {
                        Image(systemName: context.state.gainLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text(String(format: "%@$%.2f (%@%.1f%%)",
                                    context.state.gainLoss >= 0 ? "+" : "",
                                    context.state.gainLoss,
                                    context.state.gainLossPercent >= 0 ? "+" : "",
                                    context.state.gainLossPercent * 100))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(context.state.gainLoss >= 0 ? .green : .red)
                }
            }

            // Trailing Stop Status Bar
            if context.state.isTrailingStopTriggered {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.system(size: 12))
                    Text(String(format: "STOP TRIGGERED: Exceeded -%.0f%% trailing stop at $%.2f", context.attributes.trailingStopPercent, context.state.trailingStopPrice))
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.85))
                .cornerRadius(6)
            } else {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                        Text(String(format: "Trailing Stop: $%.2f (-%.0f%%)", context.state.trailingStopPrice, context.attributes.trailingStopPercent))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Text(String(format: "%.1f%% buffer", context.state.trailingStopDistancePercent))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(context.state.trailingStopDistancePercent < 5.0 ? .orange : .white.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.14),
                    Color(red: 0.12, green: 0.15, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
