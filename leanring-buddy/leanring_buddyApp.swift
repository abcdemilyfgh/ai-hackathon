//
//  leanring_buddyApp.swift
//  chris
//

import SwiftUI

@main
struct leanring_buddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("chris", id: "main") {
            MainView()
        }

        MenuBarExtra("chris", systemImage: "film.stack") {
            Button("Open chris") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Divider()
            Button("Quit chris") { NSApp.terminate(nil) }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

