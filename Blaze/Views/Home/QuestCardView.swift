import SwiftUI

/// Large tappable quest card with progress, completion state, and the
/// flame-fill + ember-burst celebration when it completes.
struct QuestCardView: View {
    @Environment(BlazeEngine.self) private var engine
    let quest: Quest
    var onTap: () -> Void

    @State private var burst = false

    var body: some View {
        Button {
            HapticsService.shared.tap()
            onTap()
        } label: {
            HStack(spacing: 14) {
                iconBadge

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(quest.title)
                            .font(.blazeHeadline)
                            .foregroundStyle(quest.completed ? .secondary : .primary)
                        if quest.verifiedByHealthKit {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(BlazeTheme.success)
                        }
                    }
                    Text(quest.progressLabel)
                        .font(.blazeCaption)
                        .foregroundStyle(.secondary)

                    if quest.metric.isHealthKitVerified && !quest.completed {
                        ProgressView(value: quest.fractionComplete)
                            .tint(BlazeTheme.ember)
                            .scaleEffect(y: 1.6, anchor: .center)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                if quest.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(BlazeTheme.success)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(quest.completed
                          ? AnyShapeStyle(LinearGradient(
                                colors: [BlazeTheme.flameOrange.opacity(0.22),
                                         BlazeTheme.flameGold.opacity(0.10)],
                                startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(Color.clear))
            )
            .blazeCard()
            .overlay(
                EmberBurstView(trigger: burst)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.45, bounce: 0.35), value: quest.completed)
        .onChange(of: quest.completed) { _, done in
            if done {
                burst = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    burst = false
                }
            }
        }
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(quest.completed
                      ? AnyShapeStyle(BlazeTheme.flameGradient)
                      : AnyShapeStyle(BlazeTheme.ember.opacity(0.15)))
                .frame(width: 52, height: 52)
            Image(systemName: quest.type.symbolName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(quest.completed ? .white : BlazeTheme.ember)
        }
    }
}
