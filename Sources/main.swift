import SwiftUI
import AppKit

@main
struct TimeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Configurar o controller do menu
        menuBarController = MenuBarController()
        
        // Ocultar o ícone do dock
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
