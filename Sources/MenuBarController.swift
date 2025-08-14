import SwiftUI
import AppKit
import Combine

class MenuBarController: NSObject, ObservableObject {
    private var statusBarItem: NSStatusItem
    private var timeTracker: TimeTracker
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init(statusBarItem: NSStatusItem) {
        self.statusBarItem = statusBarItem
        self.timeTracker = TimeTracker.shared
        super.init()
        
        setupStatusBar()
        setupTimer()
        setupBindings()
        
        // Observar mudanças na status bar para garantir visibilidade
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusBarDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    private func setupStatusBar() {
        if let button = statusBarItem.button {
            // Usar apenas ícones padrão do macOS, sem texto
            button.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "TimeTracker")
            button.image?.size = NSSize(width: 16, height: 16)
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            
            // Configurar para que seja sempre visível
            button.appearsDisabled = false
            button.imagePosition = NSControl.ImagePosition.imageOnly
            
            // Remove qualquer texto
            button.title = ""
        }
        
        statusBarItem.isVisible = true
        updateMenu()
    }
    
    @objc private func statusBarDidChange() {
        DispatchQueue.main.async {
            self.statusBarItem.isVisible = true
        }
    }
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateStatusBarTitle()
        }
    }
    
    private func setupBindings() {
        timeTracker.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async {
                    self?.updateMenu()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusBarTitle() {
        DispatchQueue.main.async {
            if let button = self.statusBarItem.button {
                // Atualizar apenas o ícone baseado no estado
                if self.timeTracker.isWorking {
                    if self.timeTracker.isPaused {
                        // Ícone de pausa
                        button.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Em Pausa")
                    } else {
                        // Ícone de play/trabalhando
                        button.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Trabalhando")
                    }
                } else {
                    // Ícone de parado
                    button.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Parado")
                }
                
                // Manter tamanho consistente
                button.image?.size = NSSize(width: 16, height: 16)
                
                // Garantir que continue visível
                self.statusBarItem.isVisible = true
            }
        }
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        
        // Status atual com tempo detalhado
        let statusItem = NSMenuItem()
        if timeTracker.isWorking {
            if timeTracker.isPaused {
                let workTime = formatDuration(timeTracker.currentSessionElapsed)
                let pauseTime = formatDuration(timeTracker.currentPauseElapsed)
                statusItem.title = "⏸️ Em Pausa | Trabalhado: \(workTime) | Pausa: \(pauseTime)"
            } else {
                let workTime = formatDuration(timeTracker.currentSessionElapsed)
                statusItem.title = "▶️ Trabalhando | Tempo: \(workTime)"
            }
        } else {
            statusItem.title = "⏹️ Parado"
        }
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Botões de controle
        if timeTracker.isWorking {
            if timeTracker.isPaused {
                let resumeItem = NSMenuItem(
                    title: "Retomar Trabalho",
                    action: #selector(resumeWork),
                    keyEquivalent: ""
                )
                resumeItem.target = self
                menu.addItem(resumeItem)
            } else {
                let pauseItem = NSMenuItem(
                    title: "Pausar Trabalho",
                    action: #selector(pauseWork),
                    keyEquivalent: ""
                )
                pauseItem.target = self
                menu.addItem(pauseItem)
            }
            
            let stopItem = NSMenuItem(
                title: "Parar Trabalho",
                action: #selector(stopWork),
                keyEquivalent: ""
            )
            stopItem.target = self
            menu.addItem(stopItem)
        } else {
            let startItem = NSMenuItem(
                title: "Iniciar Trabalho",
                action: #selector(startWork),
                keyEquivalent: ""
            )
            startItem.target = self
            menu.addItem(startItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Estatísticas do dia
        let todayStats = timeTracker.getTodayStats()
        let todayItem = NSMenuItem()
        todayItem.title = "Hoje: \(formatDuration(todayStats.totalTime)) | Extras: \(formatDuration(todayStats.overtime))"
        todayItem.isEnabled = false
        menu.addItem(todayItem)
        
        // Estatísticas da semana
        let weekStats = timeTracker.getWeekStats()
        let weekItem = NSMenuItem()
        weekItem.title = "Semana: \(formatDuration(weekStats.totalTime)) | Extras: \(formatDuration(weekStats.overtime))"
        weekItem.isEnabled = false
        menu.addItem(weekItem)
        
        // Estatísticas do mês
        let monthStats = timeTracker.getMonthStats()
        let monthItem = NSMenuItem()
        monthItem.title = "Mês: \(formatDuration(monthStats.totalTime)) | Extras: \(formatDuration(monthStats.overtime))"
        monthItem.isEnabled = false
        menu.addItem(monthItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Importar dados históricos (apenas se ainda não foi feito)
        if !timeTracker.hasImportedHistoricalOvertime() {
            let importItem = NSMenuItem(
                title: "📥 Importar Horas Extras Históricas",
                action: #selector(importHistoricalData),
                keyEquivalent: ""
            )
            importItem.target = self
            menu.addItem(importItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Usar horas extras
        if timeTracker.getTotalOvertimeBalance() > 0 {
            let useOvertimeItem = NSMenuItem(
                title: "Usar 1h Extra (Saldo: \(formatDuration(timeTracker.getTotalOvertimeBalance())))",
                action: #selector(useOvertime),
                keyEquivalent: ""
            )
            useOvertimeItem.target = self
            menu.addItem(useOvertimeItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Sair
        let quitItem = NSMenuItem(
            title: "Sair",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Opção de reset (apenas para correção)
        let resetItem = NSMenuItem(
            title: "🔄 Reset Dados",
            action: #selector(resetData),
            keyEquivalent: ""
        )
        resetItem.target = self
        menu.addItem(resetItem)
        
        statusBarItem.menu = menu
    }
    
    @objc private func statusBarButtonClicked() {
        // O menu será mostrado automaticamente
    }
    
    @objc private func startWork() {
        timeTracker.startWork()
        updateMenu()
    }
    
    @objc private func pauseWork() {
        timeTracker.pauseWork()
        updateMenu()
    }
    
    @objc private func resumeWork() {
        timeTracker.resumeWork()
        updateMenu()
    }
    
    @objc private func stopWork() {
        timeTracker.stopWork()
        updateMenu()
    }
    
    @objc private func useOvertime() {
        timeTracker.useOvertime(hours: 1)
        updateMenu()
    }
    
    @objc private func importHistoricalData() {
        timeTracker.importHistoricalOvertime()
        
        let alert = NSAlert()
        alert.messageText = "Dados Importados!"
        alert.informativeText = "Suas horas extras históricas foram importadas com sucesso:\n\n• Dia 28/7: 7h18\n• Dia 02/8: 4h20\n• Dia NN: 6h\n• Dia 07/8: 1h3\n• Dia 09/8: 4h\n• Dia 11/8: 2h48\n\nTotal: ~25,5 horas extras adicionadas ao seu saldo."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        updateMenu()
    }
    
    @objc private func resetData() {
        let alert = NSAlert()
        alert.messageText = "Reset Completo"
        alert.informativeText = "Tem certeza que deseja apagar todos os dados? Esta ação não pode ser desfeita."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancelar")
        
        if alert.runModal() == .alertFirstButtonReturn {
            timeTracker.resetAllData()
            updateMenu()
        }
    }
    
    @objc private func quit() {
        if timeTracker.isWorking {
            timeTracker.stopWork()
        }
        NSApplication.shared.terminate(nil)
    }
    
    private func formatDuration(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
