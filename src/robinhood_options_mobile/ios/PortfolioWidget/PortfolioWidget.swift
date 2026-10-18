import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Intents

// Removed AppIntent approach - using widgetURL instead for simplicity
import Intents

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), equity: 0.0, change: 0.0, changePercent: 0.0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), equity: 12345.67, change: 123.45, changePercent: 0.01)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.robinhood_options_mobile")
        let equity = userDefaults?.double(forKey: "portfolio_equity") ?? 0.0
        let change = userDefaults?.double(forKey: "portfolio_change") ?? 0.0
        let changePercent = userDefaults?.double(forKey: "portfolio_change_percent") ?? 0.0
        
        let entry = SimpleEntry(date: Date(), equity: equity, change: change, changePercent: changePercent)
        
        // Update every 15 minutes, though the app will trigger updates manually
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let equity: Double
    let change: Double
    let changePercent: Double
}

struct PortfolioWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with app name and subtle icon
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.blue.opacity(0.8))
                    .frame(width: 8, height: 8)
                Text("RealizeAlpha")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Main equity value with enhanced styling
            VStack(alignment: .leading, spacing: 2) {
                Text("Portfolio Value")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(String(format: "$%.2f", entry.equity))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            // Change indicators with better layout
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Day Change")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                    
                    HStack(spacing: 2) {
                        Image(systemName: entry.change >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8))
                            .foregroundColor(entry.change >= 0 ? .green : .red)
                        
                        Text(String(format: "$%.2f", entry.change))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(entry.change >= 0 ? .green : .red)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Change %")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                    
                    Text(String(format: "%.2f%%", entry.changePercent * 100))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(entry.change >= 0 ? .green : .red)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
    }
}

struct PortfolioWidget: Widget {
    let kind: String = "PortfolioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                PortfolioWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.08),
                                Color.purple.opacity(0.04)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                PortfolioWidgetEntryView(entry: entry)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.08),
                                Color.purple.opacity(0.04)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .configurationDisplayName("Portfolio Summary")
        .description("Track your portfolio value and daily performance at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Watchlist Widget

struct WatchlistItem: Decodable, Hashable {
    let symbol: String
    let price: Double
    let changePercent: Double
}

struct WatchlistEntry: TimelineEntry {
    let date: Date
    let items: [WatchlistItem]
    let groupWatchlistName: String?
    let groupWatchlistId: String?
    let groupId: String?
}

struct WatchlistProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> WatchlistEntry {
        WatchlistEntry(date: Date(), items: [
            WatchlistItem(symbol: "AAPL", price: 150.0, changePercent: 0.015),
            WatchlistItem(symbol: "TSLA", price: 250.0, changePercent: -0.02),
            WatchlistItem(symbol: "NVDA", price: 400.0, changePercent: 0.012),
            WatchlistItem(symbol: "MSFT", price: 300.0, changePercent: 0.005)
        ], groupWatchlistName: nil, groupWatchlistId: nil, groupId: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchlistEntry) -> ()) {
        let entry = WatchlistEntry(date: Date(), items: [
            WatchlistItem(symbol: "AAPL", price: 150.0, changePercent: 0.015),
            WatchlistItem(symbol: "TSLA", price: 250.0, changePercent: -0.02),
            WatchlistItem(symbol: "MSFT", price: 300.0, changePercent: 0.005),
            WatchlistItem(symbol: "NVDA", price: 400.0, changePercent: 0.012)
        ], groupWatchlistName: nil, groupWatchlistId: nil, groupId: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchlistEntry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.robinhood_options_mobile")
        var items: [WatchlistItem] = []
        var groupWatchlistName: String? = nil
        var groupWatchlistId: String? = nil
        var groupId: String? = nil
        
        // Check for group watchlist data first
        if let jsonString = userDefaults?.string(forKey: "group_watchlist_data"),
           let data = jsonString.data(using: .utf8) {
            do {
                items = try JSONDecoder().decode([WatchlistItem].self, from: data)
                groupWatchlistName = userDefaults?.string(forKey: "group_watchlist_name")
                groupWatchlistId = userDefaults?.string(forKey: "group_watchlist_id")
                groupId = userDefaults?.string(forKey: "group_watchlist_group_id")
            } catch {
                print("Error decoding group watchlist: \(error)")
            }
        }
        // Fall back to regular watchlist data if no group watchlist
        else if let jsonString = userDefaults?.string(forKey: "watchlist_data"),
           let data = jsonString.data(using: .utf8) {
            do {
                items = try JSONDecoder().decode([WatchlistItem].self, from: data)
            } catch {
                print("Error decoding watchlist: \(error)")
            }
        }
        
        let entry = WatchlistEntry(date: Date(), items: items, groupWatchlistName: groupWatchlistName, groupWatchlistId: groupWatchlistId, groupId: groupId)
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
}

struct WatchlistWidgetEntryView: View {
    var entry: WatchlistProvider.Entry
    
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        VStack(alignment: .leading, spacing: widgetFamily == .systemSmall ? 6 : 8) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: entry.groupWatchlistName != nil ? "person.2.fill" : "star.fill")
                    .font(.system(size: widgetFamily == .systemSmall ? 9 : 10))
                    .foregroundColor(entry.groupWatchlistName != nil ? .blue : .orange)
                Text(entry.groupWatchlistName ?? "Watchlist")
                    .font(.system(size: widgetFamily == .systemSmall ? 12 : 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            if entry.items.isEmpty {
                VStack(spacing: widgetFamily == .systemSmall ? 4 : 6) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: widgetFamily == .systemSmall ? 18 : 20))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No symbols added")
                        .font(.system(size: widgetFamily == .systemSmall ? 10 : 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: widgetFamily == .systemSmall ? 3 : 4) {
                    ForEach(Array(entry.items.prefix(widgetFamily == .systemSmall ? 3 : 4).enumerated()), id: \.element.symbol) { index, item in
                        HStack(spacing: widgetFamily == .systemSmall ? 4 : 6) {
                            // Symbol
                            Text(item.symbol)
                                .font(.system(size: widgetFamily == .systemSmall ? 12 : 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(width: widgetFamily == .systemSmall ? 40 : 50, alignment: .leading)
                            
                            Spacer()
                            
                            // Price
                            Text(String(format: widgetFamily == .systemSmall ? "%.1f" : "%.2f", item.price))
                                .font(.system(size: widgetFamily == .systemSmall ? 12 : 13, weight: .medium))
                                .foregroundColor(.primary)
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                                .frame(minWidth: widgetFamily == .systemSmall ? 40 : 50, alignment: .trailing)
                            
                            // Change percent with arrow
                            HStack(spacing: 1) {
                                Image(systemName: item.changePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: widgetFamily == .systemSmall ? 6 : 7))
                                    .foregroundColor(item.changePercent >= 0 ? .green : .red)
                                
                                Text(String(format: "%.1f%%", item.changePercent * 100))
                                    .font(.system(size: widgetFamily == .systemSmall ? 10 : 11, weight: .medium))
                                    .foregroundColor(item.changePercent >= 0 ? .green : .red)
                                    .minimumScaleFactor(0.9)
                                    .lineLimit(1)
                                    .frame(minWidth: widgetFamily == .systemSmall ? 30 : 35, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, widgetFamily == .systemSmall ? 3 : 4)
                        .padding(.horizontal, widgetFamily == .systemSmall ? 4 : 6)
                        .background(
                            RoundedRectangle(cornerRadius: widgetFamily == .systemSmall ? 4 : 6)
                                .fill(Color(UIColor.systemBackground).opacity(0.8))
                                .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 0.5)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, widgetFamily == .systemSmall ? 8 : 10)
        .padding(.vertical, widgetFamily == .systemSmall ? 10 : 12)
        .widgetURL(getWidgetURL(entry: entry))
    }
    
    private func getWidgetURL(entry: WatchlistEntry) -> URL? {
        if let groupWatchlistId = entry.groupWatchlistId, let groupId = entry.groupId {
            return URL(string: "realizealpha://group-watchlist?groupId=\(groupId)&watchlistId=\(groupWatchlistId)")
        } else {
            return URL(string: "realizealpha://watchlist")
        }
    }
}

struct WatchlistWidget: Widget {
    let kind: String = "WatchlistWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchlistProvider()) { entry in
            if #available(iOS 17.0, *) {
                WatchlistWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color(UIColor.secondarySystemBackground).opacity(0.3)
                    }
            } else {
                WatchlistWidgetEntryView(entry: entry)
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.3))
            }
        }
        .configurationDisplayName("Watchlist")
        .description("Monitor your favorite stocks and their price movements.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}


// @main removed, using PortfolioWidgetBundle.swift instead

#Preview(as: .systemSmall) {
    PortfolioWidget()
} timeline: {
    SimpleEntry(date: .now, equity: 12543.67, change: 234.56, changePercent: 0.019)
}

#Preview(as: .systemSmall) {
    WatchlistWidget()
} timeline: {
    WatchlistEntry(date: .now, items: [
        WatchlistItem(symbol: "AAPL", price: 182.52, changePercent: 0.023),
        WatchlistItem(symbol: "TSLA", price: 248.42, changePercent: -0.015),
        WatchlistItem(symbol: "NVDA", price: 875.28, changePercent: 0.045)
    ], groupWatchlistName: nil, groupWatchlistId: nil, groupId: nil)
}

#Preview(as: .systemMedium) {
    WatchlistWidget()
} timeline: {
    WatchlistEntry(date: .now, items: [
        WatchlistItem(symbol: "AAPL", price: 182.52, changePercent: 0.023),
        WatchlistItem(symbol: "TSLA", price: 248.42, changePercent: -0.015),
        WatchlistItem(symbol: "NVDA", price: 875.28, changePercent: 0.045),
        WatchlistItem(symbol: "MSFT", price: 334.12, changePercent: -0.008)
    ], groupWatchlistName: nil, groupWatchlistId: nil, groupId: nil)
}

struct TradeSignalItem: Decodable, Hashable {
    let symbol: String
    let signalType: String // "BUY", "SELL", "HOLD"
    let strength: Int // 0-100
    let timestamp: Date
    
    init(symbol: String, signalType: String, strength: Int, timestamp: Date = Date()) {
        self.symbol = symbol
        self.signalType = signalType
        self.strength = strength
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(String.self, forKey: .symbol)
        signalType = try container.decode(String.self, forKey: .signalType)
        strength = try container.decode(Int.self, forKey: .strength)
        timestamp = (try? container.decodeIfPresent(Date.self, forKey: .timestamp)) ?? Date()
    }
    
    private enum CodingKeys: String, CodingKey {
        case symbol, signalType, strength, timestamp
    }
}

struct TradeSignalsEntry: TimelineEntry {
    let date: Date
    let items: [TradeSignalItem]
}

struct TradeSignalsProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> TradeSignalsEntry {
        TradeSignalsEntry(date: Date(), items: [
            TradeSignalItem(symbol: "AAPL", signalType: "BUY", strength: 85, timestamp: Date()),
            TradeSignalItem(symbol: "TSLA", signalType: "SELL", strength: 72, timestamp: Date().addingTimeInterval(-300))
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TradeSignalsEntry) -> ()) {
        let entry = TradeSignalsEntry(date: Date(), items: [
            TradeSignalItem(symbol: "AAPL", signalType: "BUY", strength: 85, timestamp: Date()),
            TradeSignalItem(symbol: "TSLA", signalType: "SELL", strength: 72, timestamp: Date().addingTimeInterval(-300)),
            TradeSignalItem(symbol: "NVDA", signalType: "HOLD", strength: 45, timestamp: Date().addingTimeInterval(-600))
        ])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TradeSignalsEntry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.robinhood_options_mobile")
        var items: [TradeSignalItem] = []
        
        // Check for trade signals data
        if let jsonString = userDefaults?.string(forKey: "trade_signals_data") {
            print("TradeSignalsProvider: Found trade signals data: \(jsonString)")
            if let data = jsonString.data(using: .utf8) {
                do {
                    // First try to decode as array of dictionaries
                    if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        print("TradeSignalsProvider: Successfully parsed JSON array with \(jsonArray.count) items")
                        for dict in jsonArray {
                            if let symbol = dict["symbol"] as? String,
                               let signalType = dict["signalType"] as? String,
                               let strength = dict["strength"] as? Int {
                                let item = TradeSignalItem(symbol: symbol, signalType: signalType, strength: strength)
                                items.append(item)
                            }
                        }
                        print("TradeSignalsProvider: Successfully created \(items.count) TradeSignalItem objects")
                    } else {
                        // Fallback to direct decoding
                        items = try JSONDecoder().decode([TradeSignalItem].self, from: data)
                        print("TradeSignalsProvider: Successfully decoded \(items.count) items using JSONDecoder")
                    }
                } catch {
                    print("TradeSignalsProvider: Error decoding trade signals: \(error)")
                    print("TradeSignalsProvider: JSON string was: \(jsonString)")
                }
            } else {
                print("TradeSignalsProvider: Could not convert JSON string to data")
            }
        } else {
            print("TradeSignalsProvider: No trade signals data found in UserDefaults")
            // Provide some test data if no real data is available
            items = [
                TradeSignalItem(symbol: "AAPL", signalType: "BUY", strength: 85),
                TradeSignalItem(symbol: "TSLA", signalType: "SELL", strength: 72),
                TradeSignalItem(symbol: "NVDA", signalType: "HOLD", strength: 45)
            ]
            print("TradeSignalsProvider: Using test data with \(items.count) items")
        }
        
        let entry = TradeSignalsEntry(date: Date(), items: items)
        // Use a timeline that allows the app to trigger updates
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct TradeSignalsWidgetEntryView: View {
    var entry: TradeSignalsProvider.Entry
    
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        VStack(alignment: .leading, spacing: widgetFamily == .systemSmall ? 6 : 8) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: widgetFamily == .systemSmall ? 9 : 10))
                    .foregroundColor(.green)
                Text("Trade Signals")
                    .font(.system(size: widgetFamily == .systemSmall ? 12 : 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            if entry.items.isEmpty {
                VStack(spacing: widgetFamily == .systemSmall ? 4 : 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: widgetFamily == .systemSmall ? 18 : 20))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No recent signals")
                        .font(.system(size: widgetFamily == .systemSmall ? 10 : 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: widgetFamily == .systemSmall ? 3 : 4) {
                    ForEach(Array(entry.items.prefix(widgetFamily == .systemSmall ? 3 : 4).enumerated()), id: \.element.symbol) { index, item in
                        HStack(spacing: widgetFamily == .systemSmall ? 4 : 6) {
                            // Symbol
                            Text(item.symbol)
                                .font(.system(size: widgetFamily == .systemSmall ? 12 : 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(width: widgetFamily == .systemSmall ? 40 : 50, alignment: .leading)
                            
                            Spacer()
                            
                            // Signal type and strength
                            HStack(spacing: 2) {
                                Text(item.signalType)
                                    .font(.system(size: widgetFamily == .systemSmall ? 10 : 11, weight: .medium))
                                    .foregroundColor(signalColor(for: item.signalType))
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                                
                                Text("\(item.strength)%")
                                    .font(.system(size: widgetFamily == .systemSmall ? 9 : 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                            }
                            .frame(minWidth: widgetFamily == .systemSmall ? 45 : 55, alignment: .trailing)
                        }
                        .padding(.vertical, widgetFamily == .systemSmall ? 3 : 4)
                        .padding(.horizontal, widgetFamily == .systemSmall ? 4 : 6)
                        .background(
                            RoundedRectangle(cornerRadius: widgetFamily == .systemSmall ? 4 : 6)
                                .fill(Color(UIColor.systemBackground).opacity(0.8))
                                .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 0.5)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, widgetFamily == .systemSmall ? 8 : 10)
        .padding(.vertical, widgetFamily == .systemSmall ? 10 : 12)
        .widgetURL(URL(string: "realizealpha://signals"))
    }
    
    private func signalColor(for signalType: String) -> Color {
        switch signalType.uppercased() {
        case "BUY":
            return .green
        case "SELL":
            return .red
        case "HOLD":
            return .orange
        default:
            return .secondary
        }
    }
}

struct TradeSignalsWidget: Widget {
    let kind: String = "TradeSignalsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TradeSignalsProvider()) { entry in
            if #available(iOS 17.0, *) {
                TradeSignalsWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color(UIColor.secondarySystemBackground).opacity(0.3)
                    }
            } else {
                TradeSignalsWidgetEntryView(entry: entry)
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.3))
            }
        }
        .configurationDisplayName("Trade Signals")
        .description("Monitor recent trading signals and their strength.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
