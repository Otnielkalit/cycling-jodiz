import MapKit
import SwiftUI

enum CycleMapDisplayStyle: String, CaseIterable, Identifiable {
    case standard
    case hybrid
    case imagery

    var id: String { rawValue }

    static let storageKey = "cycleMapDisplayStyle"

    var title: String {
        switch self {
        case .standard:
            return String(localized: "Standard")
        case .hybrid:
            return String(localized: "Hybrid")
        case .imagery:
            return String(localized: "Satellite")
        }
    }

    var symbolName: String {
        switch self {
        case .standard:
            return "map"
        case .hybrid:
            return "square.stack.3d.up.fill"
        case .imagery:
            return "globe.americas.fill"
        }
    }

    func toMapStyle() -> MapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .automatic)
        case .hybrid:
            return .hybrid(elevation: .automatic)
        case .imagery:
            return .imagery(elevation: .automatic)
        }
    }

    static func resolved(from raw: String) -> CycleMapDisplayStyle {
        CycleMapDisplayStyle(rawValue: raw) ?? .standard
    }
}

struct CycleMapStylePickerMenu: View {
    @AppStorage(CycleMapDisplayStyle.storageKey) private var mapStyleRaw: String = CycleMapDisplayStyle.standard.rawValue
    
    var lightContent: Bool = false

    var body: some View {
        Menu {
            Picker(String(localized: "Map type"), selection: $mapStyleRaw) {
                ForEach(CycleMapDisplayStyle.allCases) { style in
                    Label(style.title, systemImage: style.symbolName)
                        .tag(style.rawValue)
                }
            }
        } label: {
            Image(systemName: CycleMapDisplayStyle.resolved(from: mapStyleRaw).symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(lightContent ? Color.white : Color.primary)
        }
        .accessibilityLabel(String(localized: "Map type"))
    }
}
