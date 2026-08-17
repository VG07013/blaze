import Foundation
import AVFoundation

enum SoundEffect: String, CaseIterable {
    case questComplete = "quest_complete"  // soft whoosh + crackle
    case streakUp = "streak_up"            // warm chime
    case milestone = "milestone"           // bigger fanfare
    case freeze = "freeze"                 // cool descending tone
    case burnout = "burnout"               // low ember fade
    case revival = "revival"               // rising from the ashes
}

/// Plays Blaze's little procedural sound set. Uses the `.ambient`
/// audio session category so the ringer/silent switch is respected.
final class SoundService {
    static let shared = SoundService()

    private var players: [SoundEffect: AVAudioPlayer] = [:]

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for effect in SoundEffect.allCases {
            if let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                players[effect] = player
            }
        }
    }

    func play(_ effect: SoundEffect) {
        guard let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }
}
