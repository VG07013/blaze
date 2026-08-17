import Foundation
import SwiftData

/// Builds each day's set of three quests from a weighted pool,
/// scaled to the user's fitness level and recent consistency.
enum QuestGenerator {

    private struct Template {
        let type: QuestType
        let metric: QuestMetric
        let title: String
        let detailFormat: String       // %@ replaced with the target
        let targets: [Double]          // index 0..2 by difficulty tier 1..3
        let unit: String
    }

    private static let templates: [Template] = [
        // Movement — HealthKit auto-verified
        Template(type: .movement, metric: .steps,
                 title: "Get moving",
                 detailFormat: "Walk %@ steps today. Blaze counts them automatically.",
                 targets: [4000, 6500, 9000], unit: "steps"),
        Template(type: .movement, metric: .walkMinutes,
                 title: "Minutes on your feet",
                 detailFormat: "Rack up %@ exercise minutes. Any pace counts.",
                 targets: [20, 30, 45], unit: "min"),

        // Strength — manual log
        Template(type: .strength, metric: .strengthSet,
                 title: "Do a set of anything",
                 detailFormat: "Push-ups, squats, curls — log %@ set(s) of whatever you like.",
                 targets: [1, 2, 3], unit: "sets"),

        // Stretch — in-app guided timer (always 5 minutes, per design)
        Template(type: .stretch, metric: .stretchMinutes,
                 title: "Guided stretch",
                 detailFormat: "A calm %@-minute stretch with a timer. Finish it and it counts.",
                 targets: [5, 5, 5], unit: "min"),

        // Wildcard — rotating pool
        Template(type: .wildcard, metric: .stairs,
                 title: "Take the stairs",
                 detailFormat: "Climb %@ flights of stairs today.",
                 targets: [5, 8, 12], unit: "flights"),
        Template(type: .wildcard, metric: .activeCalories,
                 title: "Burn it up",
                 detailFormat: "Burn %@ active calories doing anything you enjoy.",
                 targets: [150, 250, 400], unit: "kcal"),
        Template(type: .wildcard, metric: .mindfulMinutes,
                 title: "One mindful minute",
                 detailFormat: "Log %@ mindful minute(s). Even fire needs stillness.",
                 targets: [1, 1, 2], unit: "min"),
    ]

    private static let typeWeights: [QuestType: Double] = [
        .movement: 1.25, .strength: 1.0, .stretch: 1.0, .wildcard: 0.85
    ]

    /// Difficulty tier 1...3 from fitness level and the last week's completion rate.
    static func difficultyTier(profile: UserProfile, recentCompletionRate: Double) -> Int {
        var tier = min(max(profile.fitnessLevel + 1, 1), 3)
        if recentCompletionRate < 0.35 && tier > 1 { tier -= 1 }          // ease off after a rough week
        if recentCompletionRate > 0.85 && profile.streakCount >= 14 { tier += 1 }
        return min(max(tier, 1), 3)
    }

    /// Generate a new set for `day`, avoiding yesterday's exact quests:
    /// the excluded type rotates and each type's metric varies day to day.
    static func makeSet(for day: Date,
                        profile: UserProfile,
                        yesterday: DailyQuestSet?,
                        recentCompletionRate: Double) -> DailyQuestSet {
        let tier = difficultyTier(profile: profile, recentCompletionRate: recentCompletionRate)

        let yesterdayTypes = Set(yesterday?.quests.map(\.type) ?? [])
        let yesterdayExcluded = QuestType.allCases.first { !yesterdayTypes.contains($0) }
        let yesterdayMetrics = Set(yesterday?.quests.map(\.metric) ?? [])

        // Pick the type to drop today — weighted, and never the same drop two days running.
        var dropCandidates = QuestType.allCases.filter { $0 != yesterdayExcluded }
        if dropCandidates.isEmpty { dropCandidates = QuestType.allCases }
        let dropped = weightedPick(from: dropCandidates) { 1.0 / (typeWeights[$0] ?? 1.0) }

        let chosenTypes = QuestType.allCases.filter { $0 != dropped }
        let set = DailyQuestSet(day: day)
        var order = 0

        for type in chosenTypes {
            var options = templates.filter { $0.type == type }
            // Vary the metric from yesterday's when the type has alternatives.
            let fresh = options.filter { !yesterdayMetrics.contains($0.metric) }
            if !fresh.isEmpty { options = fresh }
            guard let template = options.randomElement() else { continue }

            let target = template.targets[tier - 1]
            let targetText = target == target.rounded()
                ? String(Int(target))
                : String(target)
            let quest = Quest(
                type: template.type,
                metric: template.metric,
                title: template.title,
                detail: template.detailFormat.replacingOccurrences(of: "%@", with: targetText),
                target: target,
                unit: template.unit,
                difficultyTier: tier,
                orderIndex: order
            )
            set.quests.append(quest)   // inverse (quest.set) is maintained by SwiftData
            order += 1
        }
        return set
    }

    private static func weightedPick<T>(from items: [T], weight: (T) -> Double) -> T {
        let total = items.reduce(0.0) { $0 + weight($1) }
        var roll = Double.random(in: 0..<max(total, 0.0001))
        for item in items {
            roll -= weight(item)
            if roll <= 0 { return item }
        }
        return items[items.count - 1]
    }
}
