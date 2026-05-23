import CoreLocation
import MapKit
import Observation

@MainActor
@Observable
final class RouteHubFormModel: NSObject {
    var scenario: RouteHubScenario?

    
    enum SearchSlot: Hashable {
        case loopCenter
        case start
        case end
    }

    var activeSearchSlot: SearchSlot = .loopCenter

    var loopLocationQuery = ""
    var startQuery = ""
    var endQuery = ""
    
    var distanceKmText = "20"

    
    var parsedDistanceKm: Double? {
        let raw = distanceKmText.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(raw), v > 0 else { return nil }
        return v
    }

    private(set) var completions: [MKLocalSearchCompletion] = []

    var loopCenterItem: MKMapItem?
    var startItem: MKMapItem?
    var endItem: MKMapItem?

    private let completer = MKLocalSearchCompleter()
    private var debounceTask: Task<Void, Never>?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func updateSearchRegion(center: CLLocationCoordinate2D) {
        completer.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    }

    func clearCompletions() {
        completions = []
    }

    func setScenario(_ new: RouteHubScenario) {
        scenario = new
        completions = []
        switch new {
        case .loop:
            startQuery = ""
            endQuery = ""
            startItem = nil
            endItem = nil
            activeSearchSlot = .loopCenter
        case .pointToPoint:
            loopLocationQuery = ""
            loopCenterItem = nil
            activeSearchSlot = .start
        }
        syncCompleterQueryImmediate()
    }

    func clearScenario() {
        scenario = nil
        completions = []
        activeSearchSlot = .loopCenter
        loopLocationQuery = ""
        startQuery = ""
        endQuery = ""
        loopCenterItem = nil
        startItem = nil
        endItem = nil
        distanceKmText = "20"
    }

    func setActiveSlot(_ slot: SearchSlot) {
        activeSearchSlot = slot
        syncCompleterQueryImmediate()
    }

    func scheduleCompleterQueryUpdate() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            syncCompleterQueryImmediate()
        }
    }

    private func syncCompleterQueryImmediate() {
        switch activeSearchSlot {
        case .loopCenter:
            completer.queryFragment = loopLocationQuery
        case .start:
            completer.queryFragment = startQuery
        case .end:
            completer.queryFragment = endQuery
        }
    }

    func selectCompletion(_ completion: MKLocalSearchCompletion) async throws {
        let request = MKLocalSearch.Request(completion: completion)
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else { return }
        completions = []
        switch activeSearchSlot {
        case .loopCenter:
            loopCenterItem = item
            loopLocationQuery = completion.title
        case .start:
            startItem = item
            startQuery = completion.title
        case .end:
            endItem = item
            endQuery = completion.title
        }
    }

    
    func applyYourLocation(slot: SearchSlot, location: CLLocation?) async {
        guard let coordinate = location?.coordinate else { return }
        activeSearchSlot = slot

        let geocoder = CLGeocoder()
        let title: String
        if let placemark = try? await geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)).first {
            let parts = [placemark.name, placemark.thoroughfare, placemark.locality].compactMap { $0 }
            title = parts.isEmpty ? String(localized: "Your location") : parts.joined(separator: ", ")
        } else {
            title = String(localized: "Your location")
        }

        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = title

        switch slot {
        case .loopCenter:
            loopCenterItem = item
            loopLocationQuery = title
        case .start:
            startItem = item
            startQuery = title
        case .end:
            endItem = item
            endQuery = title
        }
        completions = []
    }

    var canSubmit: Bool {
        guard let scenario else { return false }
        guard parsedDistanceKm != nil else { return false }
        switch scenario {
        case .loop:
            return loopCenterItem != nil
        case .pointToPoint:
            return startItem != nil && endItem != nil
        }
    }

    var validationHint: String? {
        guard let scenario else { return nil }
        if parsedDistanceKm == nil {
            return String(localized: "Enter a valid distance in km.")
        }
        switch scenario {
        case .loop:
            return loopCenterItem == nil ? String(localized: "Pick a place for the loop center (search or your location).") : nil
        case .pointToPoint:
            if startItem == nil { return String(localized: "Choose a start point.") }
            if endItem == nil { return String(localized: "Choose an end point.") }
            return nil
        }
    }
}

extension RouteHubFormModel: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let list = completer.results
        Task { @MainActor in
            self.completions = list
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWith error: Error) {
        Task { @MainActor in
            self.completions = []
        }
    }
}
