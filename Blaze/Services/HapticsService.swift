import Foundation
import CoreHaptics
import UIKit

/// Tactile feedback. Freeze and burnout deliberately stay silent —
/// those moments should feel quiet and different.
final class HapticsService {
    static let shared = HapticsService()

    private var engine: CHHapticEngine?
    private let supportsCoreHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    /// Light tap when a quest card is touched.
    func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium success hit on quest completion.
    func questComplete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Heavy celebratory pattern for streak increments and milestones:
    /// three rising thumps and a shimmer.
    func celebrate() {
        guard supportsCoreHaptics else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            return
        }
        do {
            if engine == nil {
                engine = try CHHapticEngine()
            }
            guard let engine else { return }
            try engine.start()

            var events: [CHHapticEvent] = []
            for (i, intensity) in [0.6, 0.8, 1.0].enumerated() {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55),
                    ],
                    relativeTime: Double(i) * 0.12
                ))
            }
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
                ],
                relativeTime: 0.4,
                duration: 0.35
            ))

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}
