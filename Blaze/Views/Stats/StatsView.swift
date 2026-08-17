import SwiftUI
import SwiftData

/// Streak history calendar plus lifetime numbers.
struct StatsView: View {
    @Environment(BlazeEngine.self) private var engine
    @Query(sort: \StreakLog.day) private var logs: [StreakLog]

    @State private var displayedMonth = Date.now.startOfDay

    var body: some View {
        NavigationStack {
            ZStack {
                BlazeBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        statTiles
                        calendarCard
                        legend
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Stats")
            .toolbarTitleDisplayMode(.inline)
        }
    }

    // MARK: Tiles

    private var statTiles: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            tile(value: "\(engine.profile.streakCount)", label: "Current streak",
                 icon: "flame.fill", color: BlazeTheme.flameOrange)
            tile(value: "\(engine.profile.longestStreak)", label: "Longest streak",
                 icon: "trophy.fill", color: BlazeTheme.flameGold)
            tile(value: "\(engine.profile.totalQuestsCompleted)", label: "Quests completed",
                 icon: "checkmark.seal.fill", color: BlazeTheme.success)
            tile(value: engine.profile.growthTier.title, label: "Blaze's form",
                 icon: "bird.fill", color: BlazeTheme.ember)
        }
    }

    private func tile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.rounded(26, .heavy))
            Text(label)
                .font(.blazeCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .blazeCard(cornerRadius: 16)
    }

    // MARK: Calendar

    private var calendarCard: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    displayedMonth = monthShifted(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthTitle)
                    .font(.blazeHeadline)
                Spacer()
                Button {
                    displayedMonth = monthShifted(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.3 : 1)
            }
            .font(.system(size: 16, weight: .semibold))

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(["M", "T", "W", "T2", "F", "S", "S2"], id: \.self) { day in
                    Text(String(day.prefix(1)))
                        .font(.blazeCaption)
                        .foregroundStyle(.tertiary)
                }
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, cell in
                    if let day = cell {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }
        }
        .padding(16)
        .blazeCard()
    }

    private func dayCell(_ day: Date) -> some View {
        let log = logs.first { Calendar.current.isDate($0.day, inSameDayAs: day) }
        let dayNumber = Calendar.current.component(.day, from: day)
        let isFuture = day > Date.now.startOfDay

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(cellColor(log: log, isFuture: isFuture))
                .frame(height: 30)
            Text("\(dayNumber)")
                .font(.rounded(12, .semibold))
                .foregroundStyle(cellTextColor(log: log, isFuture: isFuture))
        }
    }

    private func cellColor(log: StreakLog?, isFuture: Bool) -> Color {
        if isFuture { return .clear }
        guard let log else { return BlazeTheme.ash.opacity(0.12) }
        if log.freezeUsed { return BlazeTheme.freeze.opacity(0.55) }
        switch log.questsCompletedCount {
        case 3...: return BlazeTheme.flameOrange
        case 1...2: return BlazeTheme.ember.opacity(0.55)
        default: return BlazeTheme.ash.opacity(0.35)
        }
    }

    private func cellTextColor(log: StreakLog?, isFuture: Bool) -> Color {
        if isFuture { return BlazeTheme.ash.opacity(0.5) }
        if let log, log.questsCompletedCount >= 3 { return .white }
        return .primary
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendDot(BlazeTheme.flameOrange, "All 3")
            legendDot(BlazeTheme.ember.opacity(0.55), "1–2")
            legendDot(BlazeTheme.freeze.opacity(0.55), "Freeze")
            legendDot(BlazeTheme.ash.opacity(0.35), "Missed")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.blazeCaption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Month math

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
    }

    private func monthShifted(_ delta: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
    }

    /// Days of the displayed month padded with leading nils so the grid
    /// starts on Monday.
    private var monthCells: [Date?] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: displayedMonth),
              let dayCount = cal.range(of: .day, in: .month, for: displayedMonth)?.count
        else { return [] }

        let first = interval.start
        let weekday = cal.component(.weekday, from: first)   // 1 = Sunday
        let leading = (weekday + 5) % 7                       // shift so Monday = 0

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(first.addingDays(offset))
        }
        return cells
    }
}
