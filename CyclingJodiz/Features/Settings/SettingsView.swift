import SwiftUI

struct SettingsView: View {
    @AppStorage(CycleMapDisplayStyle.storageKey) private var mapStyleRaw: String = CycleMapDisplayStyle.standard.rawValue

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(String(localized: "Map type"), selection: $mapStyleRaw) {
                        ForEach(CycleMapDisplayStyle.allCases) { style in
                            Label(style.title, systemImage: style.symbolName)
                                .tag(style.rawValue)
                        }
                    }
                } header: {
                    Text(String(localized: "Map"))
                } footer: {
                    Text(String(localized: "Standard, hybrid (labels + aerial), or satellite. Same choice as the map menu on Home and route screens."))
                }

                Section("About") {
                    LabeledContent("App", value: "CyclingJodiz")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
