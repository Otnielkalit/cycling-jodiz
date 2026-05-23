//
//  ActivityView.swift
//  CyclingJodiz
//

import SwiftUI

struct ActivityView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "My Rides",
                systemImage: "figure.outdoor.cycle",
                description: Text("Saved activities will show here.")
            )
            .navigationTitle("My Rides")
        }
    }
}

#Preview {
    ActivityView()
}
