//
//  RouteFlow.swift
//  CyclingJodiz
//

import Foundation

/// Alur dari Home: **hub** → **pick** → **active ride** → **ride summary** (README screen 3–5).
enum RouteFlow: Hashable {
    case hub
    case pick(RoutePickContext)
    case activeRide(ActiveRideConfig)
    case rideSummary(RideSummaryPayload)
}
