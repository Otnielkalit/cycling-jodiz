//
//  RouteHubScenario.swift
//  CyclingJodiz
//

import Foundation

enum RouteHubScenario: String, CaseIterable, Identifiable {
    case loop
    case pointToPoint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loop: String(localized: "Loop")
        case .pointToPoint: String(localized: "A → B")
        }
    }

    var detail: String {
        switch self {
        case .loop: String(localized: "Keluar dari titik mulai lalu balik lagi ke titik yang sama (round trip di Maps)")
        case .pointToPoint: String(localized: "Titik mulai ke titik selesai")
        }
    }
}
