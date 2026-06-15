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
    @ObservedObject private var watchManager = WatchSessionManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Apple Watch Link")) {
                    HStack {
                        Label("Watch Connection", systemImage: "applewatch")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(watchManager.isReachable ? Color.green : (watchManager.isPaired ? Color.orange : Color.gray))
                                .frame(width: 8, height: 8)
                            Text(watchStatusText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if watchManager.isPaired {
                        LabeledContent("App Installed", value: watchManager.isWatchAppInstalled ? "Yes" : "No")
                        LabeledContent("App Status", value: watchManager.isReachable ? "Active & Open" : "Standby / Closed")
                    }
                    
                    if watchManager.isReachable {
                        Button {
                            watchManager.pingWatch()
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Test Ping Connection", systemImage: "waveform")
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                        }
                    }
                }

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

                Section("Developer Options") {
                    Button(role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: "com.jodiz.CyclingJodiz.savedRoutePlans.v1")
                        UserDefaults.standard.removeObject(forKey: "com.jodiz.CyclingJodiz.activities.v1")
                        // Post a notification to force views to refresh
                        NotificationCenter.default.post(name: NSNotification.Name("ResetAppDataNotification"), object: nil)
                    } label: {
                        Label("Reset App Data (Clear Cache)", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Color.cycleCanvasBackground)
        }
    }

    private var watchStatusText: String {
        if watchManager.isReachable {
            return "Connected"
        } else if watchManager.isWatchAppInstalled {
            return "Paired"
        } else if watchManager.isPaired {
            return "Missing App"
        } else {
            return "Disconnected"
        }
    }
}

#Preview {
    SettingsView()
}
