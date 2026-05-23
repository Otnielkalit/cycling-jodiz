//
//  RoutePickContext.swift
//  CyclingJodiz
//

import CoreLocation
import Foundation

/// Koordinat yang aman untuk `Hashable` / `NavigationPath`.
struct MapCoordinate: Hashable, Sendable {
    var latitude: Double
    var longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var clLocationCoordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Data yang sudah diset di hub / sheet → dipakai untuk minta rute ke MapKit.
enum RoutePickContext: Hashable, Sendable {
    /// A→B: titik jemput & tujuan tetap sama; **preferredLengthKm** = panjang ride yang diinginkan (perkiraan, boleh ± sedikit).
    case pointToPoint(start: MapCoordinate, end: MapCoordinate, preferredLengthKm: Double)
    /// Pusat loop + target km: round trip disesuaikan ke target; cycling → **mobil** (bukan jalan kaki) + ETA perkiraan sepeda + heuristik jalan.
    case loop(center: MapCoordinate, targetKm: Double)
}
