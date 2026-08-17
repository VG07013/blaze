import Foundation
import SwiftData
import SwiftUI
import WidgetKit
import UserNotifications
import UIKit

/// Full-screen emotional beats, queued so they play one at a time.
enum CelebrationEvent: Equatable, Identifiable {
    case milestone(days: Int, tier: GrowthTier)
    case revival
    case burnout
    case freezeUsed(remaining: Int)
    case perfectDay(freezeGranted: Bool)

    var id: String {
        switch self {
        case .milestone(let days, _): return "milestone.\(days)"
        case .revival:                return "revival"
        case .burnout:                return "burnout"
        case .freezeUsed:             return "freeze"
        case .perfectDay:             return "perfectDay"
        }
    }
}

/// The single source of truth for streaks, quests, rewards, and Blaze's mood.
@MainActor
@Observable
final class BlazeEngine {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    private(set) var profile: UserProfile
    private(set) var settings: AppSettings
    private(set) var todaySet: DailyQuestSet?

    /// Currently showing full-screen moment, if any.
    private(set) var celebration: CelebrationEvent?
    private var celebrationQueue: [CelebrationEvent] = []

    static let freezePrice = 500
    static let maxFreezes = 3
    static let milestones = [7, 30, 100, 365]

    // MARK: - Setup

    init(container: ModelContainer) {
        self.container = container

        let ctx = container.mainContext

        // Profile
        var profileFetch = FetchDescriptor<UserProfile>()
        profileFetch.fetchLimit = 1
        if let existing = try? ctx.fetch(profileFetch).first {
            profile = existing
        } else {
            let fresh = UserProfile()
            ctx.insert(fresh)
            profile = fresh
        }

        // Settings
        var settingsFetch = FetchDescriptor<AppSettings>()
        settingsFetch.fetchLimit = 1
        if let existing = try? ctx.fetch(settingsFetch).first {
            settings = existing
        } else {
            let fresh = AppSettings()
            ctx.insert(fresh)
            settings = fresh
        }

        seedCosmeticsIfNeeded()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        if profile.hasOnboarded {
            processDay()
        }
        try? context.save()

        NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleBecameActive() }
        }
    }

    private func seedCosmeticsIfNeeded() {
        let count = (try? context.fetchCount(FetchDescriptor<CosmeticItem>())) ?? 0
        guard count == 0 else { return }
        for item in CosmeticsCatalog.makeAll() {
            context.insert(item)
        }
    }

    // MARK: - Lifecycle

    func handleBecameActive() {
        guard profile.hasOnboarded else { return }
        processDay()
        Task { await refreshHealthProgress() }
        rescheduleNotifications()
        updateWidgetSnapshot()
        try? context.save()
    }

    // MARK: - Day rollover

    /// Settles every day that has passed since the app last looked:
    /// misses consume freezes, an unprotected miss burns the streak out,
    /// and today's quest set is generated if it doesn't exist yet.
    func processDay(now: Date = .now) {
        let today = now.startOfDay

        if profile.lastRolloverDay == nil {
            profile.lastRolloverDay = today
        }

        var cursor = profile.lastRolloverDay!
        while cursor < today {
            settle(day: cursor)
            cursor = cursor.addingDays(1)
        }
        profile.lastRolloverDay = today

        ensureQuestSet(for: today)
        recomputeBlazeState(now: now)
        upsertTodayLog()
        try? context.save()
    }

    /// Close the books on a fully elapsed day.
    private func settle(day: Date) {
        let done = questSet(for: day)?.completedCount ?? 0
        guard done == 0 else { return }  // day was safe; streak already counted at completion time

        if profile.streakCount > 0 {
            if profile.freezesHeld > 0 {
                profile.freezesHeld -= 1
                profile.lastFreezeDay = day
                writeLog(day: day, count: 0, freezeUsed: true, state: .frozen)
                enqueue(.freezeUsed(remaining: profile.freezesHeld))
            } else {
                profile.streakCount = 0
                profile.didBurnOut = true
                writeLog(day: day, count: 0, freezeUsed: false, state: .burnedOut)
                enqueue(.burnout)
                NotificationService.shared.scheduleComeback(settings: settings)
            }
        } else {
            writeLog(day: day, count: 0, freezeUsed: false, state: .burnedOut)
        }
    }

    // MARK: - Quest sets

    private func questSet(for day: Date) -> DailyQuestSet? {
        let descriptor = FetchDescriptor<DailyQuestSet>(
            predicate: #Predicate { $0.day == day }
        )
        return try? context.fetch(descriptor).first
    }

    private func ensureQuestSet(for day: Date) {
        if let existing = questSet(for: day) {
            todaySet = existing
            return
        }
        let yesterday = questSet(for: day.addingDays(-1))
        let fresh = QuestGenerator.makeSet(
            for: day,
            profile: profile,
            yesterday: yesterday,
            recentCompletionRate: recentCompletionRate()
        )
        context.insert(fresh)
        todaySet = fresh
    }

    /// Fraction of the last 7 elapsed days with at least one completion.
    private func recentCompletionRate() -> Double {
        let today = Date.now.startOfDay
        let windowStart = today.addingDays(-7)
        let descriptor = FetchDescriptor<StreakLog>(
            predicate: #Predicate { $0.day >= windowStart && $0.day < today }
        )
        guard let logs = try? context.fetch(descriptor), !logs.isEmpty else { return 0.5 }
        let activeDays = logs.filter { $0.questsCompletedCount > 0 }.count
        return Double(activeDays) / 7.0
    }

    var todayQuests: [Quest] { todaySet?.sortedQuests ?? [] }
    var questsDoneToday: Int { todaySet?.completedCount ?? 0 }

    // MARK: - Completing quests

    func emberReward(for quest: Quest) -> Int {
        10 + quest.difficultyTier * 5 + (quest.metric.isHealthKitVerified ? 5 : 0)
    }

    func xpReward(for quest: Quest) -> Int {
        20 + quest.difficultyTier * 10 + (quest.metric.isHealthKitVerified ? 10 : 0)
    }

    func completeQuest(_ quest: Quest, verified: Bool) {
        guard !quest.completed else { return }
        let today = Date.now.startOfDay

        quest.completed = true
        quest.completedAt = .now
        quest.verifiedByHealthKit = verified
        quest.progress = quest.target

        profile.totalQuestsCompleted += 1
        if verified { profile.healthVerifiedCompletions += 1 }
        profile.emberBalance += emberReward(for: quest)
        profile.xp += xpReward(for: quest)

        let doneToday = questsDoneToday
        let firstOfDay = doneToday == 1

        if settings.hapticsEnabled { HapticsService.shared.questComplete() }
        if settings.soundEnabled { SoundService.shared.play(.questComplete) }

        if firstOfDay {
            let wasBurnedOut = profile.didBurnOut && profile.streakCount == 0
            profile.streakCount += 1
            profile.longestStreak = max(profile.longestStreak, profile.streakCount)
            profile.lastQuestDay = today
            profile.didBurnOut = false
            NotificationService.shared.cancelComeback()

            if settings.hapticsEnabled { HapticsService.shared.celebrate() }
            if wasBurnedOut {
                if settings.soundEnabled { SoundService.shared.play(.revival) }
                enqueue(.revival)
            } else {
                if settings.soundEnabled { SoundService.shared.play(.streakUp) }
            }

            if Self.milestones.contains(profile.streakCount) {
                handleMilestone(days: profile.streakCount)
            }
        }

        if doneToday >= 3 {
            handlePerfectDay()
        }

        unlockEarnedCosmetics()
        profile.growthTier = GrowthTier.tier(
            streak: profile.streakCount,
            totalQuests: profile.totalQuestsCompleted
        )
        recomputeBlazeState()
        upsertTodayLog()
        rescheduleNotifications()
        updateWidgetSnapshot()
        try? context.save()
    }

    private func handleMilestone(days: Int) {
        // A 7-day streak earns a freeze.
        if days == 7 && profile.freezesHeld < Self.maxFreezes {
            profile.freezesHeld += 1
        }
        let newTier = GrowthTier.tier(streak: profile.streakCount,
                                      totalQuests: profile.totalQuestsCompleted)
        if settings.soundEnabled { SoundService.shared.play(.milestone) }
        enqueue(.milestone(days: days, tier: newTier))
        NotificationService.shared.sendMilestone(days: days, settings: settings)
    }

    /// All 3 quests done: bonus embers and XP, plus a shot at a streak
    /// freeze — HealthKit-verified days roll better odds.
    private func handlePerfectDay() {
        profile.emberBalance += 25
        profile.xp += 40

        var freezeGranted = false
        if profile.freezesHeld < Self.maxFreezes {
            let verifiedToday = todayQuests.filter { $0.completed && $0.verifiedByHealthKit }.count
            let chance = 0.15 + Double(verifiedToday) * 0.10
            if Double.random(in: 0..<1) < chance {
                freezeGranted = true
            }
            if isPerfectWeek() {
                freezeGranted = true
            }
            if freezeGranted { profile.freezesHeld += 1 }
        }
        enqueue(.perfectDay(freezeGranted: freezeGranted))
    }

    /// Seven straight days (including today) with all three quests done.
    private func isPerfectWeek() -> Bool {
        let today = Date.now.startOfDay
        let windowStart = today.addingDays(-6)
        let descriptor = FetchDescriptor<StreakLog>(
            predicate: #Predicate { $0.day >= windowStart && $0.day < today }
        )
        guard let logs = try? context.fetch(descriptor) else { return false }
        let fullDays = logs.filter { $0.questsCompletedCount >= 3 }.count
        return fullDays >= 6 && questsDoneToday >= 3
    }

    // MARK: - HealthKit sync

    func requestHealthAccess() async {
        let ok = await HealthKitService.shared.requestAuthorization()
        settings.healthKitAuthorized = ok
        try? context.save()
        if ok { await refreshHealthProgress() }
    }

    /// Pulls today's Health data into any auto-verified quests,
    /// completing them when the target is met.
    func refreshHealthProgress() async {
        guard settings.healthKitAuthorized, let set = todaySet else { return }
        for quest in set.sortedQuests where !quest.completed && quest.metric.isHealthKitVerified {
            if let value = await HealthKitService.shared.todayValue(for: quest.metric) {
                if value >= quest.target {
                    completeQuest(quest, verified: true)
                } else {
                    quest.progress = value
                }
            }
        }
        try? context.save()
        updateWidgetSnapshot()
    }

    // MARK: - Blaze's mood

    func recomputeBlazeState(now: Date = .now) {
        let today = now.startOfDay
        let newState: BlazeStateKind

        if questsDoneToday > 0 {
            newState = .thriving
        } else if profile.didBurnOut && profile.streakCount == 0 {
            newState = .burnedOut
        } else if let freezeDay = profile.lastFreezeDay,
                  freezeDay >= today.addingDays(-1) {
            newState = .frozen
        } else if now.hourOfDay >= 18 && profile.streakCount > 0 {
            newState = .worried
        } else {
            newState = .waiting
        }
        profile.blazeState = newState
    }

    var blazeState: BlazeStateKind { profile.blazeState }

    /// Blaze's home-screen line for the current mood.
    var currentSpeech: String {
        switch profile.blazeState {
        case .thriving:
            return questsDoneToday >= 3
                ? "All three?! I'm blazing. See you tomorrow. 🔥"
                : "That's the stuff. My flame's happy."
        case .waiting:
            return profile.streakCount == 0
                ? "Ready when you are. One quest lights me up."
                : "Fresh quests are in. Pick one!"
        case .worried:
            return "It's getting late… one quick quest? For me?"
        case .frozen:
            return "Phew… the freeze saved us. Wake me with a quest."
        case .burnedOut:
            return "My fire went out… one quest brings me back."
        case .rising:
            return "YES. I'm back. Let's never do that again."
        }
    }

    // MARK: - Celebrations

    private func enqueue(_ event: CelebrationEvent) {
        celebrationQueue.append(event)
        if celebration == nil {
            celebration = celebrationQueue.removeFirst()
        }
    }

    func dismissCelebration() {
        celebration = celebrationQueue.isEmpty ? nil : celebrationQueue.removeFirst()
    }

    // MARK: - Cosmetics & shop

    func cosmetics(in category: CosmeticCategory) -> [CosmeticItem] {
        let raw = category.rawValue
        let descriptor = FetchDescriptor<CosmeticItem>(
            predicate: #Predicate { $0.categoryRaw == raw },
            sortBy: [SortDescriptor(\.price)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    var allCosmetics: [CosmeticItem] {
        (try? context.fetch(FetchDescriptor<CosmeticItem>())) ?? []
    }

    /// Marks milestone/quest-count cosmetics owned the moment they're earned.
    private func unlockEarnedCosmetics() {
        for item in allCosmetics where !item.owned && !item.isPurchasable && !item.isStarter {
            let streakOK = item.unlockStreak > 0 && profile.streakCount >= item.unlockStreak
            let questsOK = item.unlockQuests > 0 && profile.totalQuestsCompleted >= item.unlockQuests
            if streakOK || questsOK {
                item.owned = true
                item.acquiredAt = .now
            }
        }
    }

    func purchase(_ item: CosmeticItem) -> Bool {
        guard item.isPurchasable, !item.owned, profile.emberBalance >= item.price else { return false }
        profile.emberBalance -= item.price
        item.owned = true
        item.acquiredAt = .now
        try? context.save()
        return true
    }

    func buyFreeze() -> Bool {
        guard profile.freezesHeld < Self.maxFreezes,
              profile.emberBalance >= Self.freezePrice else { return false }
        profile.emberBalance -= Self.freezePrice
        profile.freezesHeld += 1
        rescheduleNotifications()
        updateWidgetSnapshot()
        try? context.save()
        return true
    }

    func equip(_ item: CosmeticItem) {
        guard item.owned else { return }
        switch item.category {
        case .flameColor: profile.equippedFlameColorID = item.itemID
        case .blazeSkin:  profile.equippedSkinID = item.itemID
        case .appTheme:   profile.equippedThemeID = item.itemID
        case .appIcon:
            profile.equippedIconID = item.itemID
            UIApplication.shared.setAlternateIconName(
                CosmeticsCatalog.iconAssetName(for: item.itemID)
            )
        }
        updateWidgetSnapshot()
        try? context.save()
    }

    func isEquipped(_ item: CosmeticItem) -> Bool {
        switch item.category {
        case .flameColor: return profile.equippedFlameColorID == item.itemID
        case .blazeSkin:  return profile.equippedSkinID == item.itemID
        case .appTheme:   return profile.equippedThemeID == item.itemID
        case .appIcon:    return profile.equippedIconID == item.itemID
        }
    }

    // MARK: - Onboarding

    func requestNotificationAccess() async -> Bool {
        let granted = await NotificationService.shared.requestAuthorization()
        settings.notificationsEnabled = granted
        try? context.save()
        return granted
    }

    func completeOnboarding(fitnessLevel: Int, reminderMinutes: Int) {
        profile.fitnessLevel = fitnessLevel
        settings.reminderMinutes = reminderMinutes
        profile.hasOnboarded = true
        processDay()
        rescheduleNotifications()
        updateWidgetSnapshot()
        try? context.save()
    }

    // MARK: - Logs, notifications, widget

    private func writeLog(day: Date, count: Int, freezeUsed: Bool, state: BlazeStateKind) {
        if let existing = fetchLog(day: day) {
            existing.questsCompletedCount = count
            existing.freezeUsed = freezeUsed
            existing.blazeStateRaw = state.rawValue
        } else {
            context.insert(StreakLog(day: day, questsCompletedCount: count,
                                     freezeUsed: freezeUsed, blazeState: state))
        }
    }

    private func fetchLog(day: Date) -> StreakLog? {
        let descriptor = FetchDescriptor<StreakLog>(
            predicate: #Predicate { $0.day == day }
        )
        return try? context.fetch(descriptor).first
    }

    private func upsertTodayLog() {
        let today = Date.now.startOfDay
        if let existing = fetchLog(day: today) {
            existing.questsCompletedCount = questsDoneToday
            existing.blazeStateRaw = profile.blazeState.rawValue
        } else {
            context.insert(StreakLog(day: today, questsCompletedCount: questsDoneToday,
                                     freezeUsed: false, blazeState: profile.blazeState))
        }
    }

    func rescheduleNotifications() {
        NotificationService.shared.reschedule(
            settings: settings,
            profile: profile,
            questsDoneToday: questsDoneToday
        )
    }

    func updateWidgetSnapshot() {
        WidgetSnapshot(
            dayStamp: Date.now.startOfDay,
            streak: profile.streakCount,
            questsDone: questsDoneToday,
            questsTotal: max(todayQuests.count, 3),
            stateRaw: profile.blazeState.rawValue,
            tierRaw: profile.growthTier.rawValue,
            flameColorID: profile.equippedFlameColorID,
            skinID: profile.equippedSkinID,
            freezesHeld: profile.freezesHeld
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
