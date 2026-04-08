import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GarageTabView()
                .environment(\.managedObjectContext, viewContext)
                .tag(0)
                .tabItem {
                    Label("GARAGE", systemImage: "car.fill")
                }

            DealCheckTabView()
                .environment(\.managedObjectContext, viewContext)
                .tag(1)
                .tabItem {
                    Label("DEAL CHECK", systemImage: "target")
                }

            MarketTabView()
                .environment(\.managedObjectContext, viewContext)
                .tag(2)
                .tabItem {
                    Label("MARKET", systemImage: "diamond.fill")
                }

            WatchlistTabView()
                .environment(\.managedObjectContext, viewContext)
                .tag(3)
                .tabItem {
                    Label("WATCHLIST", systemImage: "eye.circle")
                }

            SignalsTabView()
                .environment(\.managedObjectContext, viewContext)
                .tag(4)
                .tabItem {
                    Label("SIGNALS", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
        .tint(GIQ.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            configureTabBarAppearance()
            BackgroundRefreshService.shared.performForegroundRefresh(context: viewContext)
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.35)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.35),
            .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        ]
        itemAppearance.selected.iconColor = UIColor(red: 0.83, green: 0.66, blue: 0.26, alpha: 1)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.83, green: 0.66, blue: 0.26, alpha: 1),
            .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .bold)
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
