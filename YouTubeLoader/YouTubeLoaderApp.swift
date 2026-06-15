import SwiftUI

@main
struct YouTubeLoaderApp: App {
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var telemetry = TelemetryService.shared

    @State private var showSetup = false
    @State private var skippedSetup = false

    private var needsSetup: Bool {
        !YtDlpService.shared.hasExportedCookies
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(downloadManager)
                .environmentObject(telemetry)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    if needsSetup && !skippedSetup {
                        showSetup = true
                    }
                }
                .sheet(isPresented: $showSetup) {
                    SetupView(
                        onComplete: {
                            showSetup = false
                        },
                        onSkip: {
                            skippedSetup = true
                            showSetup = false
                        }
                    )
                    .interactiveDismissDisabled()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1000, height: 650)

        Settings {
            SettingsView()
        }
    }
}
