import SwiftUI
import SwiftData

@main
struct BlazeApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer
    @State private var engine: BlazeEngine

    init() {
        let schema = Schema([
            UserProfile.self,
            AppSettings.self,
            DailyQuestSet.self,
            Quest.self,
            CosmeticItem.self,
            StreakLog.self,
        ])
        let modelContainer: ModelContainer
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create SwiftData container: \(error)")
        }
        container = modelContainer
        _engine = State(initialValue: BlazeEngine(container: modelContainer))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .modelContainer(container)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                engine.handleBecameActive()
            }
        }
    }
}
