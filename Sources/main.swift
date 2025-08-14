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
    private var statusBarItem: NSStatusItem!
    private var menuBarController: MenuBarController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Criar o item da status bar com tamanho mínimo para ícone apenas
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // Configurar para nunca ser removido automaticamente
        statusBarItem.behavior = []
        statusBarItem.isVisible = true
        
        // Configurar o controller do menu
        menuBarController = MenuBarController(statusBarItem: statusBarItem)
        
        // Ocultar o ícone do dock
        NSApp.setActivationPolicy(.accessory)
        
        // Timer para garantir visibilidade (menos frequente já que é menor)
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.statusBarItem.isVisible = true
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
