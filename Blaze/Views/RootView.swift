import SwiftUI

enum AppTab: Hashable {
    case home, blaze, shop, stats, settings
}

struct RootView: View {
    @Environment(BlazeEngine.self) private var engine
    @Environment(\.colorScheme) private var scheme
    @State private var selectedTab: AppTab = .home

    var body: some View {
        Group {
            if engine.profile.hasOnboarded {
                mainTabs
            } else {
                OnboardingView()
            }
        }
        .overlay {
            if let event = engine.celebration {
                CelebrationOverlayView(event: event)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: engine.celebration)
        .onOpenURL { url in
            if url.scheme == "blaze" { selectedTab = .home }
        }
        .tint(BlazeTheme.ember)
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "flame.fill") }
                .tag(AppTab.home)
            CosmeticsView()
                .tabItem { Label("Blaze", systemImage: "bird.fill") }
                .tag(AppTab.blaze)
            ShopView()
                .tabItem { Label("Shop", systemImage: "bag.fill") }
                .tag(AppTab.shop)
            StatsView()
                .tabItem { Label("Stats", systemImage: "calendar") }
                .tag(AppTab.stats)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }
}

/// Shared screen background: warm charcoal (or warm off-white) with a
/// soft radial wash so it never reads flat.
struct BlazeBackground: View {
    @Environment(BlazeEngine.self) private var engine
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            BlazeTheme.background(for: engine.profile.equippedThemeID, scheme: scheme)
                .ignoresSafeArea()
            BlazeTheme.backgroundWash(scheme: scheme)
                .ignoresSafeArea()
        }
    }
}
