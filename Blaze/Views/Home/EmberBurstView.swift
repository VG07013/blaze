import SwiftUI

/// A one-shot burst of embers rising and fading. Drop it in an overlay
/// and flip `trigger` to fire it.
struct EmberBurstView: View {
    var trigger: Bool
    var colors: [Color] = [BlazeTheme.flameOrange, BlazeTheme.flameGold, BlazeTheme.ember]
    var particleCount: Int = 22
    var duration: Double = 1.3

    @State private var startDate: Date?

    var body: some View {
        ZStack {
            if let startDate {
                TimelineView(.animation(minimumInterval: 1.0 / 40.0)) { timeline in
                    Canvas { context, size in
                        let age = timeline.date.timeIntervalSince(startDate)
                        guard age >= 0, age <= duration else { return }
                        let progress = age / duration
                        let cx = size.width / 2
                        let baseY = size.height * 0.62

                        for i in 0..<particleCount {
                            let seed = Double(i) * 12.9898
                            let rand1 = abs(sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
                            let rand2 = abs(sin(seed * 1.7) * 24634.6345).truncatingRemainder(dividingBy: 1)
                            let rand3 = abs(sin(seed * 2.3) * 91723.1523).truncatingRemainder(dividingBy: 1)

                            let angle = (rand1 - 0.5) * .pi * 0.9 - .pi / 2   // mostly upward
                            let speed = (0.45 + rand2 * 0.55) * size.height
                            let x = cx + cos(angle) * speed * progress * 0.7
                            let y = baseY + sin(angle) * speed * progress + 0.25 * size.height * progress * progress
                            let radius = (2.0 + rand3 * 3.5) * (1.0 - progress * 0.6)
                            let opacity = (1.0 - progress) * (0.7 + rand2 * 0.3)

                            let rect = CGRect(x: x - radius, y: y - radius,
                                              width: radius * 2, height: radius * 2)
                            context.opacity = opacity
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(colors[i % colors.count])
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .onChange(of: trigger) { _, fired in
            if fired {
                startDate = .now
                Task {
                    try? await Task.sleep(for: .seconds(duration + 0.1))
                    startDate = nil
                }
            }
        }
    }
}
