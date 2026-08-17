import ActivityKit
import WidgetKit
import SwiftUI

/// Lock-screen and Dynamic Island UI for an in-progress stretch quest.
struct StretchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StretchActivityAttributes.self) { context in
            // Lock screen banner
            HStack(spacing: 14) {
                FlameShape()
                    .fill(BlazeTheme.flameGradient)
                    .frame(width: 26, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.questTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("Stretching — keep breathing")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(timerInterval: Date.now...max(Date.now.addingTimeInterval(1), context.state.endDate), countsDown: true)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(BlazeTheme.ember)
                    .frame(width: 84, alignment: .trailing)
            }
            .padding(16)
            .activityBackgroundTint(Color(hex: 0x12100E))
            .activitySystemActionForegroundColor(BlazeTheme.ember)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FlameShape()
                        .fill(BlazeTheme.flameGradient)
                        .frame(width: 20, height: 27)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.questTitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...max(Date.now.addingTimeInterval(1), context.state.endDate), countsDown: true)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(BlazeTheme.ember)
                        .frame(width: 64, alignment: .trailing)
                }
            } compactLeading: {
                FlameShape()
                    .fill(BlazeTheme.flameGradient)
                    .frame(width: 12, height: 16)
            } compactTrailing: {
                Text(timerInterval: Date.now...max(Date.now.addingTimeInterval(1), context.state.endDate), countsDown: true)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(BlazeTheme.ember)
                    .frame(width: 44)
            } minimal: {
                FlameShape()
                    .fill(BlazeTheme.flameGradient)
                    .frame(width: 10, height: 14)
            }
        }
    }
}
