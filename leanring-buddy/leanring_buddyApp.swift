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
        Window("Snappy", id: "main") {
            MainView()
        }

        MenuBarExtra("Snappy", systemImage: "film.stack") {
            Button("Open Snappy") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Divider()
            Button("Quit Snappy") { NSApp.terminate(nil) }
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

