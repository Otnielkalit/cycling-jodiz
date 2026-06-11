//
//  RootTabView.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import SwiftUI

enum AppTab: Hashable {
    case home
    case activity
    case settings
}

struct RootTabView: View {
    @State private var selected: AppTab = .home

    var body: some View {
        TabView(selection: $selected) {
            HomeView()
                .tabItem { Label("Home", systemImage: "safari") }
                .tag(AppTab.home)

            ActivityView()
                .tabItem { Label("Activity", systemImage: "figure.outdoor.cycle") }
                .tag(AppTab.activity)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Color.cycleAccent)
    }
}

#Preview {
    RootTabView()
}
