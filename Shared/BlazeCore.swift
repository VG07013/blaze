import Foundation

// MARK: - App group (shared between app and widget)

enum BlazeAppGroup {
    static let identifier = "group.com.blaze.app"
    static let snapshotKey = "blaze.widget.snapshot"
}

enum BlazeDeepLink {
    static let today = URL(string: "blaze://today")!
}

// MARK: - Blaze emotional states

enum BlazeStateKind: String, Codable, CaseIterable {
    case thriving   // streak active, quest done today
    case waiting    // quests not done yet, calm
    case worried    // evening, nothing done, flame dims
    case frozen     // a streak freeze was auto-used
    case burnedOut  // streak died, pile of embers
    case rising     // revival after burnout

    var isDormant: Bool { self == .frozen || self == .burnedOut }
}

// MARK: - Growth tiers

enum GrowthTier: Int, Codable, CaseIterable, Comparable {
    case spark = 1
    case ember = 2
    case flame = 3
    case inferno = 4
    case eternal = 5

    var title: String {
        switch self {
        case .spark:   return "Spark"
        case .ember:   return "Ember"
        case .flame:   return "Flame"
        case .inferno: return "Inferno"
        case .eternal: return "Eternal"
        }
    }

    var subtitle: String {
        switch self {
        case .spark:   return "A tiny hatchling with a brave little flame."
        case .ember:   return "Brighter now, plumage coming in."
        case .flame:   return "Full-grown and burning strong."
        case .inferno: return "Majestic. Radiant. Unmistakable."
        case .eternal: return "A fire that simply does not go out."
        }
    }

    /// Relative visual scale of Blaze at this tier.
    var visualScale: Double { 0.62 + Double(rawValue) * 0.095 }

    static func < (lhs: GrowthTier, rhs: GrowthTier) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Tier from streak length and lifetime quests, whichever is further along.
    static func tier(streak: Int, totalQuests: Int) -> GrowthTier {
        if streak >= 365 { return .eternal }
        if streak >= 100 || totalQuests >= 500 { return .inferno }
        if streak >= 30 || totalQuests >= 180 { return .flame }
        if streak >= 7 || totalQuests >= 30 { return .ember }
        return .spark
    }

    /// What it takes to reach the next tier, for progress UI.
    var nextTierHint: String? {
        switch self {
        case .spark:   return "Reach a 7-day streak or 30 total quests"
        case .ember:   return "Reach a 30-day streak or 180 total quests"
        case .flame:   return "Reach a 100-day streak or 500 total quests"
        case .inferno: return "Reach a 365-day streak"
        case .eternal: return nil
        }
    }
}

// MARK: - Widget snapshot

/// Tiny state capsule the app writes to the shared app group so the
/// widget can render without touching the database.
struct WidgetSnapshot: Codable {
    var dayStamp: Date          // start-of-day the snapshot describes
    var streak: Int
    var questsDone: Int
    var questsTotal: Int
    var stateRaw: String
    var tierRaw: Int
    var flameColorID: String
    var skinID: String
    var freezesHeld: Int

    var state: BlazeStateKind { BlazeStateKind(rawValue: stateRaw) ?? .waiting }
    var tier: GrowthTier { GrowthTier(rawValue: tierRaw) ?? .spark }

    static let placeholder = WidgetSnapshot(
        dayStamp: Calendar.current.startOfDay(for: .now),
        streak: 12,
        questsDone: 1,
        questsTotal: 3,
        stateRaw: BlazeStateKind.thriving.rawValue,
        tierRaw: GrowthTier.ember.rawValue,
        flameColorID: "flame.classic",
        skinID: "skin.classic",
        freezesHeld: 2
    )

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: BlazeAppGroup.identifier)?
            .data(forKey: BlazeAppGroup.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: BlazeAppGroup.identifier)?.set(data, forKey: BlazeAppGroup.snapshotKey)
    }

    /// Quests done as of `date` — a stale snapshot from yesterday means today is 0.
    func displayQuestsDone(at date: Date) -> Int {
        Calendar.current.isDate(dayStamp, inSameDayAs: date) ? questsDone : 0
    }

    /// Best-guess emotional state at render time, so the widget turns
    /// "worried" in the evening even if the app hasn't been opened.
    func displayState(at date: Date) -> BlazeStateKind {
        let sameDay = Calendar.current.isDate(dayStamp, inSameDayAs: date)
        let hour = Calendar.current.component(.hour, from: date)
        if sameDay {
            if questsDone > 0 { return state == .rising ? .rising : .thriving }
            if state.isDormant { return state }
            return hour >= 18 ? .worried : .waiting
        }
        // Snapshot is from a previous day.
        if streak == 0 { return .burnedOut }
        return hour >= 18 ? .worried : .waiting
    }
}

// MARK: - Date helpers

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    var hourOfDay: Int { Calendar.current.component(.hour, from: self) }

    var minutesIntoDay: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
