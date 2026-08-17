import SwiftUI

/// Instructions plus the right completion affordance for each quest type:
/// auto-synced progress for HealthKit metrics, a manual log button for
/// strength, and the guided timer for stretches.
struct QuestDetailView: View {
    @Environment(BlazeEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    let quest: Quest

    @State private var confirmingLog = false

    var body: some View {
        NavigationStack {
            ZStack {
                BlazeBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        headerBadge

                        Text(quest.title)
                            .font(.blazeTitle)
                            .multilineTextAlignment(.center)

                        Text(quest.detail)
                            .font(.blazeBody)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)

                        rewardRow

                        if quest.completed {
                            completedPanel
                        } else {
                            switch quest.metric {
                            case .strengthSet:
                                strengthPanel
                            case .stretchMinutes:
                                StretchTimerView(quest: quest)
                            default:
                                healthPanel
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(quest.type.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.blazeHeadline)
                }
            }
        }
    }

    // MARK: Pieces

    private var headerBadge: some View {
        ZStack {
            Circle()
                .fill(quest.completed
                      ? AnyShapeStyle(BlazeTheme.flameGradient)
                      : AnyShapeStyle(BlazeTheme.ember.opacity(0.15)))
                .frame(width: 88, height: 88)
            Image(systemName: quest.completed ? "checkmark" : quest.type.symbolName)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(quest.completed ? .white : BlazeTheme.ember)
        }
        .warmGlow(radius: quest.completed ? 20 : 0)
        .padding(.top, 8)
    }

    private var rewardRow: some View {
        HStack(spacing: 18) {
            Label("\(engine.emberReward(for: quest)) embers", systemImage: "flame.circle.fill")
                .foregroundStyle(BlazeTheme.ember)
            Label("\(engine.xpReward(for: quest)) XP", systemImage: "arrow.up.circle.fill")
                .foregroundStyle(BlazeTheme.flameGold)
            if quest.metric.isHealthKitVerified {
                Label("Auto-verified", systemImage: "heart.fill")
                    .foregroundStyle(BlazeTheme.success)
            }
        }
        .font(.blazeCaption)
    }

    private var completedPanel: some View {
        VStack(spacing: 10) {
            Text("Quest complete!")
                .font(.blazeHeadline)
            Text(quest.verifiedByHealthKit
                 ? "Verified by Health. Honest fire burns brightest."
                 : "Logged. Blaze believes in you.")
                .font(.blazeBody)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .blazeCard()
    }

    private var healthPanel: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(BlazeTheme.ash.opacity(0.25), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: quest.fractionComplete)
                    .stroke(BlazeTheme.flameGradient,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.6), value: quest.fractionComplete)
                VStack(spacing: 2) {
                    Text("\(Int(quest.progress.rounded()))")
                        .font(.rounded(34, .heavy))
                    Text("of \(Int(quest.target)) \(quest.unit)")
                        .font(.blazeCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 170, height: 170)
            .padding(.top, 6)

            if engine.settings.healthKitAuthorized {
                Label("Syncing with Health", systemImage: "heart.fill")
                    .font(.blazeCaption)
                    .foregroundStyle(BlazeTheme.success)
                Button {
                    Task { await engine.refreshHealthProgress() }
                } label: {
                    Label("Refresh now", systemImage: "arrow.clockwise")
                        .font(.blazeHeadline)
                }
                .buttonStyle(.bordered)
            } else {
                Text("Connect Health and this quest completes itself as you move.")
                    .font(.blazeCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await engine.requestHealthAccess() }
                } label: {
                    Label("Connect Health", systemImage: "heart.fill")
                        .font(.blazeHeadline)
                }
                .buttonStyle(.borderedProminent)
                .tint(BlazeTheme.flameOrange)

                Button("Mark done manually") {
                    engine.completeQuest(quest, verified: false)
                }
                .font(.blazeCaption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .blazeCard()
    }

    private var strengthPanel: some View {
        VStack(spacing: 16) {
            Text("Any set counts — push-ups, squats, resistance bands, a heavy grocery haul done with intent.")
                .font(.blazeBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                confirmingLog = true
            } label: {
                Text("I did it 💪")
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
            .confirmationDialog("Log this set?", isPresented: $confirmingLog, titleVisibility: .visible) {
                Button("Yes, I really did it") {
                    engine.completeQuest(quest, verified: false)
                }
                Button("Not yet", role: .cancel) {}
            } message: {
                Text("Blaze runs on the honor system. Honest fire burns brightest.")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .blazeCard()
    }
}
