import WidgetKit
import SwiftUI

// MARK: - Timeline

struct BlazeEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct BlazeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BlazeEntry {
        BlazeEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BlazeEntry) -> Void) {
        completion(BlazeEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BlazeEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load() ?? .placeholder
        let now = Date.now

        // Re-render at the moments Blaze's mood can change without the
        // app running: 6pm (worried) and midnight (new day).
        var entries: [BlazeEntry] = [BlazeEntry(date: now, snapshot: snapshot)]
        let cal = Calendar.current
        if let evening = cal.date(bySettingHour: 18, minute: 0, second: 0, of: now), evening > now {
            entries.append(BlazeEntry(date: evening, snapshot: snapshot))
        }
        let midnight = now.startOfDay.addingDays(1)
        entries.append(BlazeEntry(date: midnight, snapshot: snapshot))

        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(300))))
    }
}

// MARK: - Widget

struct BlazeWidget: Widget {
    let kind = "BlazeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BlazeTimelineProvider()) { entry in
            BlazeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hex: 0x1A130C), Color(hex: 0x12100E)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .widgetURL(BlazeDeepLink.today)
        }
        .configurationDisplayName("Blaze")
        .description("Your streak, your phoenix, and today's quest progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct BlazeWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BlazeEntry

    private var state: BlazeStateKind { entry.snapshot.displayState(at: entry.date) }
    private var done: Int { entry.snapshot.displayQuestsDone(at: entry.date) }

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var small: some View {
        VStack(spacing: 6) {
            BlazeAvatarView(
                state: state,
                tier: entry.snapshot.tier,
                flameColorID: entry.snapshot.flameColorID,
                skinID: entry.snapshot.skinID,
                size: 72,
                animated: false
            )
            HStack(spacing: 5) {
                flameIcon(size: 16)
                Text("\(entry.snapshot.streak)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(streakStyle)
            }
            progressRing(size: 26, lineWidth: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            BlazeAvatarView(
                state: state,
                tier: entry.snapshot.tier,
                flameColorID: entry.snapshot.flameColorID,
                skinID: entry.snapshot.skinID,
                size: 110,
                animated: false
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    flameIcon(size: 22)
                    Text("\(entry.snapshot.streak)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(streakStyle)
                    Text("days")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    progressRing(size: 22, lineWidth: 3.5)
                    Text("\(done)/\(entry.snapshot.questsTotal) quests today")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text(statusLine)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Bits

    private var streakStyle: AnyShapeStyle {
        if entry.snapshot.streak > 0 && !state.isDormant {
            return AnyShapeStyle(BlazeTheme.flameGradient)
        }
        return AnyShapeStyle(BlazeTheme.ash)
    }

    @ViewBuilder
    private func flameIcon(size: CGFloat) -> some View {
        if state == .frozen {
            Image(systemName: "snowflake")
                .font(.system(size: size))
                .foregroundStyle(BlazeTheme.freeze)
        } else {
            FlameShape()
                .fill(BlazeTheme.flameFill(BlazeTheme.flameColors(for: entry.snapshot.flameColorID)))
                .frame(width: size * 0.75, height: size)
                .opacity(state == .burnedOut ? 0.35 : 1)
        }
    }

    private func progressRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(BlazeTheme.ash.opacity(0.3), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: Double(done) / Double(max(entry.snapshot.questsTotal, 1)))
                .stroke(BlazeTheme.flameGradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }

    private var statusLine: String {
        switch state {
        case .thriving:  return "Blaze is thriving 🔥"
        case .waiting:   return "Quests are waiting"
        case .worried:   return "Blaze is getting worried…"
        case .frozen:    return "Freeze used — wake him up"
        case .burnedOut: return "Do a quest to revive Blaze"
        case .rising:    return "Back from the ashes!"
        }
    }
}
