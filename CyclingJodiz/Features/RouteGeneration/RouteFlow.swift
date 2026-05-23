import Foundation

enum RouteFlow: Hashable {
    case hub
    case pick(RoutePickContext)
    case activeRide(ActiveRideConfig)
    case rideSummary(RideSummaryPayload)
}
