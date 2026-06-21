//
//  leanring_buddyApp.swift
//  Clip Assistant
//

import ServiceManagement
import SwiftUI
import Sparkle

@main
struct leanring_buddyApp: App {
    @NSApplicationDelegateAdaptor(CompanionAppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Chris", id: "main") {
            MainView()
        }

        MenuBarExtra("Chris", systemImage: "film.stack") {
            Button("Open Chris") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Divider()
            Button("Quit Chris") { NSApp.terminate(nil) }
        }
    }
}

/// App lifecycle. Clicky's companion UI (menu-bar panel, popup, cursor follower,
/// voice pipeline) is intentionally disabled — this is now Clip Assistant.
@MainActor
final class CompanionAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarPanelManager: MenuBarPanelManager?
    private let companionManager = CompanionManager()
    private var sparkleUpdaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🎬 Clip Assistant: Starting...")

        UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 0])

        ClickyAnalytics.configure()
        ClickyAnalytics.trackAppOpened()

        // --- Clicky companion UI disabled (menu-bar panel, popup, blue cursor follower) ---
        // menuBarPanelManager = MenuBarPanelManager(companionManager: companionManager)
        // companionManager.start()
        // if !companionManager.hasCompletedOnboarding || !companionManager.allPermissionsGranted {
        //     menuBarPanelManager?.showPanelOnLaunch()
        // }
        // registerAsLoginItemIfNeeded()
        // startSparkleUpdater()

        // Behave like a normal windowed app (dock icon + focused window).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // companionManager.stop()
    }

    private func registerAsLoginItemIfNeeded() {
        let loginItemService = SMAppService.mainApp
        if loginItemService.status != .enabled {
            do {
                try loginItemService.register()
            } catch {
                print("⚠️ Failed to register as login item: \(error)")
            }
        }
    }

    private func startSparkleUpdater() {
        let updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.sparkleUpdaterController = updaterController
        do {
            try updaterController.updater.start()
        } catch {
            print("⚠️ Sparkle updater failed to start: \(error)")
        }
    }
}

