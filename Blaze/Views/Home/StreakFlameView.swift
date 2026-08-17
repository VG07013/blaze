import SwiftUI

/// The streak counter: a living flame with the biggest number in the app.
struct StreakFlameView: View {
    var streak: Int
    var flameColorID: String
    var state: BlazeStateKind

    var body: some View {
        HStack(spacing: 14) {
            flame
            VStack(alignment: .leading, spacing: 0) {
                Text("\(streak)")
                    .font(.blazeStreak)
                    .foregroundStyle(
                        streak > 0 && !state.isDormant
                            ? AnyShapeStyle(BlazeTheme.flameGradient)
                            : AnyShapeStyle(BlazeTheme.ash)
                    )
                    .contentTransition(.numericText(value: Double(streak)))
                    .animation(.spring(duration: 0.5, bounce: 0.4), value: streak)
                Text("day streak")
                    .font(.blazeHeadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var flame: some View {
        if state == .frozen {
            Image(systemName: "snowflake")
                .font(.system(size: 44))
                .foregroundStyle(BlazeTheme.freeze)
                .shadow(color: BlazeTheme.freeze.opacity(0.6), radius: 12)
        } else if streak == 0 || state == .burnedOut {
            FlameShape()
                .fill(BlazeTheme.ash.opacity(0.5))
                .frame(width: 40, height: 54)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                LayeredFlame(
                    colors: BlazeTheme.flameColors(for: flameColorID),
                    phase: timeline.date.timeIntervalSinceReferenceDate * 3.2,
                    dimmed: state == .worried
                )
                .frame(width: 44, height: 60)
            }
            .warmGlow(radius: 18)
        }
    }
}
