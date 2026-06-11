//
//  RouteFlow.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import Foundation

enum RouteFlow: Hashable {
    case hub
    case pick(RoutePickContext)
    case activeRide(ActiveRideConfig)
    case rideSummary(RideSummaryPayload)
}
