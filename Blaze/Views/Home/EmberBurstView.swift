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
                    Canvas { context, canvasSize in
                        let age: Double = timeline.date.timeIntervalSince(startDate)
                        guard age >= 0, age <= duration else { return }
                        let progress: Double = age / duration
                        let width: Double = Double(canvasSize.width)
                        let height: Double = Double(canvasSize.height)
                        let cx: Double = width / 2.0
                        let baseY: Double = height * 0.62

                        for i in 0..<particleCount {
                            let seed: Double = Double(i) * 12.9898
                            let rand1: Double = abs(sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
                            let rand2: Double = abs(sin(seed * 1.7) * 24634.6345).truncatingRemainder(dividingBy: 1)
                            let rand3: Double = abs(sin(seed * 2.3) * 91723.1523).truncatingRemainder(dividingBy: 1)

                            // Mostly upward fan with a touch of gravity pulling back down
                            let angle: Double = (rand1 - 0.5) * Double.pi * 0.9 - Double.pi / 2.0
                            let speed: Double = (0.45 + rand2 * 0.55) * height
                            let x: Double = cx + cos(angle) * speed * progress * 0.7
                            let rise: Double = sin(angle) * speed * progress
                            let gravity: Double = 0.25 * height * progress * progress
                            let y: Double = baseY + rise + gravity
                            let radius: Double = (2.0 + rand3 * 3.5) * (1.0 - progress * 0.6)
                            let particleOpacity: Double = (1.0 - progress) * (0.7 + rand2 * 0.3)

                            let rect = CGRect(x: x - radius, y: y - radius,
                                              width: radius * 2.0, height: radius * 2.0)
                            context.opacity = particleOpacity
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
