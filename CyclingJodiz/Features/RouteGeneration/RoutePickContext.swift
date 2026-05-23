import CoreLocation
import Foundation

struct MapCoordinate: Hashable, Sendable, Codable {
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

enum RoutePickContext: Hashable, Sendable, Codable {
    
    case pointToPoint(start: MapCoordinate, end: MapCoordinate, preferredLengthKm: Double)
    
    case loop(center: MapCoordinate, targetKm: Double)
}
