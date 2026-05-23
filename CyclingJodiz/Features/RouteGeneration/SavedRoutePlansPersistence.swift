import Foundation

struct SavedRoutePlan: Identifiable, Codable, Hashable {
    let id: UUID
    
    let plannedStart: Date
    
    let savedAt: Date
    let config: ActiveRideConfig
}

enum SavedRoutePlansPersistence {
    private static let key = "com.jodiz.CyclingJodiz.savedRoutePlans.v1"
    private static let maxPlans = 30

    static func load() -> [SavedRoutePlan] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedRoutePlan].self, from: data)) ?? []
    }

    static func append(_ plan: SavedRoutePlan) {
        var all = load()
        all.insert(plan, at: 0)
        if all.count > maxPlans {
            all = Array(all.prefix(maxPlans))
        }
        guard let data = try? JSONEncoder().encode(all) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
