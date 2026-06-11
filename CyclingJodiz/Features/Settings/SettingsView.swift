//
//  SettingsView.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(CycleMapDisplayStyle.storageKey) private var mapStyleRaw: String = CycleMapDisplayStyle.standard.rawValue
    @AppStorage(CycleAppColorScheme.storageKey) private var appColorSchemeRaw: String = CycleAppColorScheme.system.rawValue

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

                Section {
                    Picker(String(localized: "Appearance"), selection: $appColorSchemeRaw) {
                        ForEach(CycleAppColorScheme.allCases) { scheme in
                            Label(scheme.title, systemImage: scheme.iconName)
                                .tag(scheme.rawValue)
                        }
                    }
                } header: {
                    Text(String(localized: "Appearance"))
                } footer: {
                    Text(String(localized: "Choose light mode, dark mode, or system default appearance."))
                }

                Section("About") {
                    LabeledContent("App", value: "CyclingJodiz")
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Color.cycleCanvasBackground)
        }
    }
}

#Preview {
    SettingsView()
}
