//
//  ActivityPersistence.swift
//  CyclingJodiz
//
//  Created by otnielkalit on 11/06/26.
//

import Foundation
import SwiftUI

enum ActivityPersistence {
    private static let key = "com.jodiz.CyclingJodiz.activities.v1"
    private static let maxActivities = 50

    static func load() -> [RideSummaryPayload] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RideSummaryPayload].self, from: data)) ?? []
    }

    static func append(_ activity: RideSummaryPayload) {
        var all = load()
        all.insert(activity, at: 0)
        if all.count > maxActivities {
            all = Array(all.prefix(maxActivities))
        }
        guard let data = try? JSONEncoder().encode(all) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func delete(at indexSet: IndexSet) {
        var all = load()
        all.remove(atOffsets: indexSet)
        guard let data = try? JSONEncoder().encode(all) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func loadLast() -> RideSummaryPayload? {
        load().first
    }
}
