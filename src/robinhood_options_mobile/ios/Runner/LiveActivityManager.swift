//
//  LiveActivityManager.swift
//  Runner
//
//  RealizeAlpha - iOS Live Activities & Dynamic Island Manager
//  Bridges ActivityKit lifecycle to Flutter MethodChannel.
//

import Foundation
import ActivityKit
import Flutter

@available(iOS 16.1, *)
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

@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private init() {}

    func areActivitiesEnabled() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func startActivity(data: [String: Any]) throws -> String {
        guard areActivitiesEnabled() else {
            throw NSError(
                domain: "LiveActivity",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Live Activities are disabled by user or system"]
            )
        }

        let positionId = data["positionId"] as? String ?? UUID().uuidString
        let symbol = data["symbol"] as? String ?? ""
        let strategy = data["strategy"] as? String ?? ""
        let strikePrice = (data["strikePrice"] as? NSNumber)?.doubleValue ?? 0.0
        let expirationDate = data["expirationDate"] as? String ?? ""
        let optionType = data["optionType"] as? String ?? "call"
        let quantity = (data["quantity"] as? NSNumber)?.doubleValue ?? 1.0
        let direction = data["direction"] as? String ?? "debit"
        let averageOpenPrice = (data["averageOpenPrice"] as? NSNumber)?.doubleValue ?? 0.0
        let trailingStopPercent = (data["trailingStopPercent"] as? NSNumber)?.doubleValue ?? 10.0
        let is0DTE = data["is0DTE"] as? Bool ?? false
        let dte = (data["dte"] as? NSNumber)?.intValue ?? 0

        let currentPrice = (data["currentPrice"] as? NSNumber)?.doubleValue ?? 0.0
        let marketValue = (data["marketValue"] as? NSNumber)?.doubleValue ?? 0.0
        let gainLoss = (data["gainLoss"] as? NSNumber)?.doubleValue ?? 0.0
        let gainLossPercent = (data["gainLossPercent"] as? NSNumber)?.doubleValue ?? 0.0
        let changeToday = (data["changeToday"] as? NSNumber)?.doubleValue ?? 0.0
        let changePercentToday = (data["changePercentToday"] as? NSNumber)?.doubleValue ?? 0.0
        let peakPrice = (data["peakPrice"] as? NSNumber)?.doubleValue ?? currentPrice
        let trailingStopPrice = (data["trailingStopPrice"] as? NSNumber)?.doubleValue ?? 0.0
        let trailingStopDistancePercent = (data["trailingStopDistancePercent"] as? NSNumber)?.doubleValue ?? 0.0
        let isTrailingStopTriggered = data["isTrailingStopTriggered"] as? Bool ?? false
        let statusText = data["statusText"] as? String ?? "Active"
        let lastUpdatedMillis = (data["lastUpdatedMillis"] as? NSNumber)?.doubleValue ?? (Date().timeIntervalSince1970 * 1000)

        let attributes = OptionPositionAttributes(
            positionId: positionId,
            symbol: symbol,
            strategy: strategy,
            strikePrice: strikePrice,
            expirationDate: expirationDate,
            optionType: optionType,
            quantity: quantity,
            direction: direction,
            averageOpenPrice: averageOpenPrice,
            trailingStopPercent: trailingStopPercent,
            is0DTE: is0DTE,
            dte: dte
        )

        let state = OptionPositionAttributes.ContentState(
            currentPrice: currentPrice,
            marketValue: marketValue,
            gainLoss: gainLoss,
            gainLossPercent: gainLossPercent,
            changeToday: changeToday,
            changePercentToday: changePercentToday,
            peakPrice: peakPrice,
            trailingStopPrice: trailingStopPrice,
            trailingStopDistancePercent: trailingStopDistancePercent,
            isTrailingStopTriggered: isTrailingStopTriggered,
            statusText: statusText,
            lastUpdatedMillis: lastUpdatedMillis
        )

        // Dismiss any existing activities for the same position to avoid duplicates
        for existingActivity in Activity<OptionPositionAttributes>.activities {
            if existingActivity.attributes.positionId == positionId {
                Task {
                    await existingActivity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }

        let activity: Activity<OptionPositionAttributes>
        if #available(iOS 16.2, *) {
            let content = ActivityContent(
                state: state,
                staleDate: Calendar.current.date(byAdding: .hour, value: 4, to: Date())
            )
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } else {
            activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
        }

        return activity.id
    }

    func updateActivity(data: [String: Any]) async {
        let positionId = data["positionId"] as? String ?? ""
        let activityId = data["activityId"] as? String

        let currentPrice = (data["currentPrice"] as? NSNumber)?.doubleValue ?? 0.0
        let marketValue = (data["marketValue"] as? NSNumber)?.doubleValue ?? 0.0
        let gainLoss = (data["gainLoss"] as? NSNumber)?.doubleValue ?? 0.0
        let gainLossPercent = (data["gainLossPercent"] as? NSNumber)?.doubleValue ?? 0.0
        let changeToday = (data["changeToday"] as? NSNumber)?.doubleValue ?? 0.0
        let changePercentToday = (data["changePercentToday"] as? NSNumber)?.doubleValue ?? 0.0
        let peakPrice = (data["peakPrice"] as? NSNumber)?.doubleValue ?? currentPrice
        let trailingStopPrice = (data["trailingStopPrice"] as? NSNumber)?.doubleValue ?? 0.0
        let trailingStopDistancePercent = (data["trailingStopDistancePercent"] as? NSNumber)?.doubleValue ?? 0.0
        let isTrailingStopTriggered = data["isTrailingStopTriggered"] as? Bool ?? false
        let statusText = data["statusText"] as? String ?? "Active"
        let lastUpdatedMillis = (data["lastUpdatedMillis"] as? NSNumber)?.doubleValue ?? (Date().timeIntervalSince1970 * 1000)

        let state = OptionPositionAttributes.ContentState(
            currentPrice: currentPrice,
            marketValue: marketValue,
            gainLoss: gainLoss,
            gainLossPercent: gainLossPercent,
            changeToday: changeToday,
            changePercentToday: changePercentToday,
            peakPrice: peakPrice,
            trailingStopPrice: trailingStopPrice,
            trailingStopDistancePercent: trailingStopDistancePercent,
            isTrailingStopTriggered: isTrailingStopTriggered,
            statusText: statusText,
            lastUpdatedMillis: lastUpdatedMillis
        )

        for activity in Activity<OptionPositionAttributes>.activities {
            if (activityId != nil && activity.id == activityId) || activity.attributes.positionId == positionId {
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(
                        state: state,
                        staleDate: Calendar.current.date(byAdding: .hour, value: 4, to: Date())
                    )
                    await activity.update(content)
                } else {
                    await activity.update(using: state)
                }
            }
        }
    }

    func endActivity(positionId: String, activityId: String?) async {
        for activity in Activity<OptionPositionAttributes>.activities {
            if (activityId != nil && activity.id == activityId) || activity.attributes.positionId == positionId {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func getActiveActivities() -> [[String: Any]] {
        return Activity<OptionPositionAttributes>.activities.map { activity in
            return [
                "id": activity.id,
                "positionId": activity.attributes.positionId,
                "symbol": activity.attributes.symbol,
                "is0DTE": activity.attributes.is0DTE,
                "currentPrice": activity.content.state.currentPrice,
                "isTrailingStopTriggered": activity.content.state.isTrailingStopTriggered
            ]
        }
    }
}
