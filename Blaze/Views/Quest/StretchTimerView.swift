import SwiftUI
import ActivityKit

/// Five-minute guided stretch timer. Runs on the wall clock so it keeps
/// counting in the background, shows a Live Activity while running, and
/// completes the quest when time is up. Survives app relaunch via
/// AppStorage.
struct StretchTimerView: View {
    @Environment(BlazeEngine.self) private var engine
    let quest: Quest

    @AppStorage("stretch.endTimestamp") private var storedEnd: Double = 0
    @AppStorage("stretch.questID") private var storedQuestID: String = ""

    @State private var endDate: Date?
    @State private var activity: Activity<StretchActivityAttributes>?
    @State private var finished = false

    private var totalSeconds: Int { Int(quest.target * 60) }

    var body: some View {
        VStack(spacing: 16) {
            if let endDate, !finished {
                runningView(endDate: endDate)
            } else {
                idleView
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .blazeCard()
        .onAppear(perform: restoreIfNeeded)
    }

    // MARK: States

    private var idleView: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.cooldown")
                .font(.system(size: 44))
                .foregroundStyle(BlazeTheme.ember)
            Text("\(Int(quest.target)) minutes of easy stretching. Neck, shoulders, hips, hamstrings — wherever the day landed.")
                .font(.blazeBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                start()
            } label: {
                Label("Start stretch", systemImage: "play.fill")
                    .font(.blazeHeadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(BlazeTheme.flameGradient)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func runningView(endDate: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let remaining = endDate.timeIntervalSince(timeline.date)
            if remaining <= 0 {
                Color.clear
                    .frame(height: 1)
                    .onAppear { finish() }
            } else {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(BlazeTheme.ash.opacity(0.25), lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: 1.0 - remaining / Double(totalSeconds))
                            .stroke(BlazeTheme.flameGradient,
                                    style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text(timerString(remaining))
                                .font(.rounded(40, .heavy))
                                .monospacedDigit()
                            Text("keep breathing")
                                .font(.blazeCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 180, height: 180)

                    Text(guidanceLine(remaining: remaining))
                        .font(.blazeBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)

                    Button("Give up", role: .destructive) {
                        cancel()
                    }
                    .font(.blazeCaption)
                }
            }
        }
    }

    // MARK: Timer control

    private func start() {
        let end = Date.now.addingTimeInterval(Double(totalSeconds))
        endDate = end
        storedEnd = end.timeIntervalSince1970
        storedQuestID = quest.id.uuidString
        HapticsService.shared.tap()
        startLiveActivity(end: end)
    }

    private func restoreIfNeeded() {
        guard storedQuestID == quest.id.uuidString, storedEnd > 0 else { return }
        let end = Date(timeIntervalSince1970: storedEnd)
        if end <= .now {
            finish()
        } else {
            endDate = end
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        clearStorage()
        endLiveActivity()
        engine.completeQuest(quest, verified: false)
    }

    private func cancel() {
        endDate = nil
        clearStorage()
        endLiveActivity()
    }

    private func clearStorage() {
        storedEnd = 0
        storedQuestID = ""
    }

    // MARK: Live Activity

    private func startLiveActivity(end: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = StretchActivityAttributes(
            questTitle: quest.title,
            totalSeconds: totalSeconds
        )
        let state = StretchActivityAttributes.ContentState(endDate: end)
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: end)
        )
    }

    private func endLiveActivity() {
        guard let activity else { return }
        let state = StretchActivityAttributes.ContentState(endDate: .now)
        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: .now),
                dismissalPolicy: .immediate
            )
        }
        self.activity = nil
    }

    // MARK: Copy

    private func timerString(_ remaining: TimeInterval) -> String {
        let secs = max(Int(remaining.rounded()), 0)
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    private func guidanceLine(remaining: TimeInterval) -> String {
        let elapsed = Double(totalSeconds) - remaining
        let phase = Int(elapsed / (Double(totalSeconds) / 5.0))
        switch phase {
        case 0: return "Roll your neck slowly — three circles each way."
        case 1: return "Shoulders: big backward rolls, then reach for the sky."
        case 2: return "Hips: gentle circles, then a low lunge each side."
        case 3: return "Hamstrings: soft forward fold, knees easy."
        default: return "Last stretch — anything that still feels tight. Almost there."
        }
    }
}
