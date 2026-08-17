import Foundation
import SwiftData

// MARK: - Quest vocabulary

enum QuestType: String, Codable, CaseIterable {
    case movement, strength, stretch, wildcard

    var displayName: String {
        switch self {
        case .movement: return "Movement"
        case .strength: return "Strength"
        case .stretch:  return "Stretch"
        case .wildcard: return "Wildcard"
        }
    }

    var symbolName: String {
        switch self {
        case .movement: return "figure.walk"
        case .strength: return "dumbbell.fill"
        case .stretch:  return "figure.cooldown"
        case .wildcard: return "sparkles"
        }
    }
}

enum QuestMetric: String, Codable, CaseIterable {
    case steps
    case walkMinutes
    case stairs
    case activeCalories
    case mindfulMinutes
    case strengthSet
    case stretchMinutes

    /// Metrics Blaze can verify automatically through HealthKit.
    var isHealthKitVerified: Bool {
        switch self {
        case .strengthSet, .stretchMinutes: return false
        default: return true
        }
    }
}

// MARK: - Player profile

@Model
final class UserProfile {
    var streakCount: Int = 0
    var longestStreak: Int = 0
    var freezesHeld: Int = 0
    var emberBalance: Int = 0
    var xp: Int = 0
    var totalQuestsCompleted: Int = 0
    var healthVerifiedCompletions: Int = 0
    var blazeStateRaw: String = BlazeStateKind.waiting.rawValue
    var growthTierRaw: Int = GrowthTier.spark.rawValue

    // Equipped cosmetics, one per category
    var equippedFlameColorID: String = "flame.classic"
    var equippedSkinID: String = "skin.classic"
    var equippedThemeID: String = "theme.hearth"
    var equippedIconID: String = "icon.primary"

    // Streak bookkeeping
    var lastQuestDay: Date?      // start-of-day of the last day with >=1 completion
    var lastRolloverDay: Date?   // start-of-day through which misses were processed
    var lastFreezeDay: Date?     // start-of-day a freeze last auto-applied
    var didBurnOut: Bool = false // true from burnout until the next completion

    // Onboarding
    var hasOnboarded: Bool = false
    var fitnessLevel: Int = 1    // 0 gentle, 1 steady, 2 fierce
    var createdAt: Date = Date.now

    init() {}

    var blazeState: BlazeStateKind {
        get { BlazeStateKind(rawValue: blazeStateRaw) ?? .waiting }
        set { blazeStateRaw = newValue.rawValue }
    }

    var growthTier: GrowthTier {
        get { GrowthTier(rawValue: growthTierRaw) ?? .spark }
        set { growthTierRaw = newValue.rawValue }
    }

    /// Level curve: 100 XP for level 2, +60 XP more per level after.
    static func levelInfo(forXP xp: Int) -> (level: Int, into: Int, needed: Int) {
        var level = 1
        var remaining = xp
        var needed = 100
        while remaining >= needed {
            remaining -= needed
            level += 1
            needed = 100 + (level - 1) * 60
        }
        return (level, remaining, needed)
    }

    var level: Int { Self.levelInfo(forXP: xp).level }
}

// MARK: - Quests

@Model
final class Quest {
    var id: UUID = UUID()
    var typeRaw: String = QuestType.movement.rawValue
    var metricRaw: String = QuestMetric.steps.rawValue
    var title: String = ""
    var detail: String = ""
    var target: Double = 0
    var unit: String = ""
    var difficultyTier: Int = 1
    var orderIndex: Int = 0
    var progress: Double = 0
    var completed: Bool = false
    var verifiedByHealthKit: Bool = false
    var completedAt: Date?
    var set: DailyQuestSet?

    init(type: QuestType, metric: QuestMetric, title: String, detail: String,
         target: Double, unit: String, difficultyTier: Int, orderIndex: Int) {
        self.typeRaw = type.rawValue
        self.metricRaw = metric.rawValue
        self.title = title
        self.detail = detail
        self.target = target
        self.unit = unit
        self.difficultyTier = difficultyTier
        self.orderIndex = orderIndex
    }

    var type: QuestType { QuestType(rawValue: typeRaw) ?? .movement }
    var metric: QuestMetric { QuestMetric(rawValue: metricRaw) ?? .steps }

    var fractionComplete: Double {
        guard target > 0 else { return completed ? 1 : 0 }
        return completed ? 1 : min(progress / target, 1)
    }

    var progressLabel: String {
        switch metric {
        case .strengthSet:
            return completed ? "Logged" : "Tap to log"
        case .stretchMinutes:
            return completed ? "Done" : "\(Int(target)) min guided timer"
        default:
            return "\(Int(progress.rounded())) / \(Int(target)) \(unit)"
        }
    }
}

@Model
final class DailyQuestSet {
    @Attribute(.unique) var day: Date = Date.now.startOfDay
    @Relationship(deleteRule: .cascade, inverse: \Quest.set) var quests: [Quest] = []

    init(day: Date) {
        self.day = day
    }

    var sortedQuests: [Quest] { quests.sorted { $0.orderIndex < $1.orderIndex } }
    var completedCount: Int { quests.filter(\.completed).count }
}

// MARK: - Cosmetics

enum CosmeticCategory: String, Codable, CaseIterable {
    case blazeSkin, flameColor, appTheme, appIcon

    var displayName: String {
        switch self {
        case .blazeSkin:  return "Plumage"
        case .flameColor: return "Flame Colors"
        case .appTheme:   return "Themes"
        case .appIcon:    return "App Icons"
        }
    }
}

enum CosmeticRarity: String, Codable {
    case common, rare, milestone

    var displayName: String {
        switch self {
        case .common:    return "Common"
        case .rare:      return "Rare"
        case .milestone: return "Milestone"
        }
    }
}

@Model
final class CosmeticItem {
    @Attribute(.unique) var itemID: String = ""
    var name: String = ""
    var detail: String = ""
    var categoryRaw: String = CosmeticCategory.flameColor.rawValue
    var rarityRaw: String = CosmeticRarity.common.rawValue
    var price: Int = 0          // embers; 0 means not purchasable
    var unlockStreak: Int = 0   // streak milestone requirement (0 = none)
    var unlockQuests: Int = 0   // total-quests requirement (0 = none)
    var isStarter: Bool = false
    var owned: Bool = false
    var acquiredAt: Date?

    init(itemID: String, name: String, detail: String, category: CosmeticCategory,
         rarity: CosmeticRarity, price: Int = 0, unlockStreak: Int = 0,
         unlockQuests: Int = 0, isStarter: Bool = false) {
        self.itemID = itemID
        self.name = name
        self.detail = detail
        self.categoryRaw = category.rawValue
        self.rarityRaw = rarity.rawValue
        self.price = price
        self.unlockStreak = unlockStreak
        self.unlockQuests = unlockQuests
        self.isStarter = isStarter
        self.owned = isStarter
    }

    var category: CosmeticCategory { CosmeticCategory(rawValue: categoryRaw) ?? .flameColor }
    var rarity: CosmeticRarity { CosmeticRarity(rawValue: rarityRaw) ?? .common }
    var isPurchasable: Bool { price > 0 }

    var unlockDescription: String {
        if isStarter { return "Starter" }
        if unlockStreak > 0 { return "\(unlockStreak)-day streak" }
        if unlockQuests > 0 { return "\(unlockQuests) total quests" }
        if price > 0 { return "\(price) embers" }
        return "Locked"
    }
}

// MARK: - Streak history

@Model
final class StreakLog {
    @Attribute(.unique) var day: Date = Date.now.startOfDay
    var questsCompletedCount: Int = 0
    var freezeUsed: Bool = false
    var blazeStateRaw: String = BlazeStateKind.waiting.rawValue

    init(day: Date, questsCompletedCount: Int = 0, freezeUsed: Bool = false,
         blazeState: BlazeStateKind = .waiting) {
        self.day = day
        self.questsCompletedCount = questsCompletedCount
        self.freezeUsed = freezeUsed
        self.blazeStateRaw = blazeState.rawValue
    }

    var blazeState: BlazeStateKind { BlazeStateKind(rawValue: blazeStateRaw) ?? .waiting }
}

// MARK: - Settings

@Model
final class AppSettings {
    var notificationsEnabled: Bool = true
    var morningEnabled: Bool = true
    var middayEnabled: Bool = false
    var eveningEnabled: Bool = true
    var lastChanceEnabled: Bool = true
    var freezeAlertsEnabled: Bool = true
    var milestoneEnabled: Bool = true
    var comebackEnabled: Bool = true

    var reminderMinutes: Int = 9 * 60        // morning nudge, default 9:00
    var quietStartMinutes: Int = 22 * 60     // quiet hours 22:00 –
    var quietEndMinutes: Int = 8 * 60        // – 08:00

    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var healthKitAuthorized: Bool = false

    init() {}

    /// Whether a given minute-of-day falls inside the quiet-hours window.
    func isQuiet(minuteOfDay: Int) -> Bool {
        if quietStartMinutes == quietEndMinutes { return false }
        if quietStartMinutes < quietEndMinutes {
            return minuteOfDay >= quietStartMinutes && minuteOfDay < quietEndMinutes
        }
        // Window wraps midnight
        return minuteOfDay >= quietStartMinutes || minuteOfDay < quietEndMinutes
    }
}
