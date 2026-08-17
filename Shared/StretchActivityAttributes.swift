import Foundation
import ActivityKit

/// Live Activity attributes for an in-progress guided stretch quest.
/// Shared between the app (which starts/ends the activity) and the
/// widget extension (which renders it).
struct StretchActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Wall-clock moment the stretch timer completes.
        var endDate: Date
    }

    /// Title of the stretch quest, fixed for the life of the activity.
    var questTitle: String
    /// Total planned duration in seconds.
    var totalSeconds: Int
}
