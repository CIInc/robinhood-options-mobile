//
//  PortfolioWidgetBundle.swift
//  PortfolioWidget
//
//  Created by Aymeric Grassart on 2/9/26.
//

import WidgetKit
import SwiftUI

@main
struct PortfolioWidgetBundle: WidgetBundle {
    var body: some Widget {
        PortfolioWidget()
        WatchlistWidget()
        TradeSignalsWidget()
        PortfolioWidgetControl()
        PortfolioWidgetLiveActivity()
    }
}
