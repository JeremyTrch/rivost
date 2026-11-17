import SafariServices
import SwiftUI

@main
struct RiVOSTApp: App {
    @State private var store = ShowtimesStore()

    init() {
        URLCache.shared = URLCache(memoryCapacity: 40 << 20, diskCapacity: 300 << 20)

        let ink = UIColor(RV.ink)
        let serif = UIFont.systemFont(ofSize: 34, weight: .semibold).fontDescriptor.withDesign(.serif)
        let inlineSerif = UIFont.systemFont(ofSize: 17, weight: .semibold).fontDescriptor.withDesign(.serif)
        let bar = UINavigationBar.appearance()
        if let serif { bar.largeTitleTextAttributes = [.font: UIFont(descriptor: serif, size: 34), .foregroundColor: ink] }
        if let inlineSerif { bar.titleTextAttributes = [.font: UIFont(descriptor: inlineSerif, size: 17), .foregroundColor: ink] }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(RV.goldHot)
        }
    }
}

enum AppTab: Hashable {
    case films, agenda, cinemas, search
}

struct RootView: View {
    @Environment(ShowtimesStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .films
    @State private var safari: SafariItem?

    var body: some View {
        ZStack {
            if store.hasData {
                tabs.transition(.opacity)
            } else if let message = store.errorMessage, !store.isLoading {
                ErrorScreen(message: message) { Task { await store.load() } }
                    .transition(.opacity)
            } else {
                SplashView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: store.hasData)
        .task { await store.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, store.isStale { Task { await store.load() } }
        }
        .environment(\.openURL, OpenURLAction { url in
            let scheme = url.scheme?.lowercased()
            guard scheme == "http" || scheme == "https", url.host() != "maps.apple.com" else { return .systemAction }
            safari = SafariItem(url: url)
            return .handled
        })
        .sheet(item: $safari) { item in
            SafariView(url: item.url).ignoresSafeArea()
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Films", systemImage: "film.stack", value: AppTab.films) { FilmsView() }
            Tab("Agenda", systemImage: "clock", value: AppTab.agenda) { AgendaView() }
            Tab("Cinémas", systemImage: "popcorn", value: AppTab.cinemas) { CinemasView() }
            Tab(value: AppTab.search, role: .search) { SearchView() }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sensoryFeedback(.selection, trigger: tab)
    }
}

// MARK: - Launch states

struct SplashView: View {
    @State private var risen: CGFloat = 0

    var body: some View {
        ZStack {
            RivieraBackground()
            VStack(spacing: 22) {
                SunsetMark(risen: risen)
                    .frame(width: 132, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
                    .shadow(color: RV.gold.opacity(0.25), radius: 40, y: 10)
                Logotype(size: 52)
                HStack(spacing: 10) {
                    ProgressView().tint(RV.gold)
                    Text("Chargement des séances…")
                        .font(.system(size: 14))
                        .foregroundStyle(RV.mist)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6)) { risen = 1 }
        }
    }
}

struct ErrorScreen: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            RivieraBackground()
            VStack(spacing: 14) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(RV.gold)
                Text("Séances indisponibles")
                    .font(.display(28))
                    .foregroundStyle(RV.ink)
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(RV.mist)
                    .multilineTextAlignment(.center)
                Button("Réessayer", systemImage: "arrow.clockwise", action: retry)
                    .buttonStyle(.glassProminent)
                    .tint(RV.gold)
                    .controlSize(.large)
                    .padding(.top, 10)
            }
            .padding(32)
        }
    }
}

struct Logotype: View {
    var size: CGFloat = 64

    var body: some View {
        Text("Ri\(Text("VOST").foregroundStyle(RV.goldGradient))")
            .font(.display(size, .medium))
            .tracking(-size * 0.025)
            .foregroundStyle(RV.ink)
            .accessibilityLabel("RiVOST")
    }
}

// MARK: - In-app ticketing

struct SafariItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(RV.goldHot)
        controller.preferredBarTintColor = UIColor(RV.night)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
