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
            DispatchQueue.main.async {
                self.updateStatusBarTitle()
                // Se estiver trabalhando, recriar o menu completamente para garantir atualização
                if self.timeTracker.isWorking {
                    self.updateMenu()
                }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    private func setupBindings() {
        timeTracker.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async {
                    self?.updateStatusBarTitle()
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
    
    private func updateMenuContent() {
        guard let menu = statusBarItem.menu, menu.items.count > 0 else { return }
        
        // Debug: print para verificar se está sendo chamado
        // print("Atualizando menu - isWorking: \(timeTracker.isWorking)")
        
        // Atualizar o primeiro item (status) - sempre no índice 0
        let statusItem = menu.items[0]
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
        
        // Atualizar outros itens do menu
        for item in menu.items {
            if item.title.hasPrefix("Hoje:") {
                let todayStats = timeTracker.getTodayStats()
                item.title = "Hoje: \(formatDuration(todayStats.totalTime)) | Extras: \(formatDuration(todayStats.overtime))"
            } else if item.title.hasPrefix("Semana:") {
                let weekStats = timeTracker.getWeekStats()
                item.title = "Semana: \(formatDuration(weekStats.totalTime)) | Extras: \(formatDuration(weekStats.overtime))"
            } else if item.title.hasPrefix("Mês:") {
                let monthStats = timeTracker.getMonthStats()
                item.title = "Mês: \(formatDuration(monthStats.totalTime)) | Extras: \(formatDuration(monthStats.overtime))"
            } else if item.title.contains("Saldo:") {
                item.title = "Usar 1h Extra (Saldo: \(formatDuration(timeTracker.getTotalOvertimeBalance())))"
            }
        }
    }
    
    private func updateMenu() {
        DispatchQueue.main.async {
            let menu = NSMenu()
            
            // Status atual com tempo detalhado - sempre atualizado
            let statusItem = NSMenuItem()
            if self.timeTracker.isWorking {
                if self.timeTracker.isPaused {
                    let workTime = self.formatDuration(self.timeTracker.currentSessionElapsed)
                    let pauseTime = self.formatDuration(self.timeTracker.currentPauseElapsed)
                    statusItem.title = "⏸️ Em Pausa | Trabalhado: \(workTime) | Pausa: \(pauseTime)"
                } else {
                    let workTime = self.formatDuration(self.timeTracker.currentSessionElapsed)
                    statusItem.title = "▶️ Trabalhando | Tempo: \(workTime)"
                }
            } else {
                statusItem.title = "⏹️ Parado"
            }
            statusItem.isEnabled = false
            menu.addItem(statusItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // Botões de controle
            if self.timeTracker.isWorking {
                if self.timeTracker.isPaused {
                    let resumeItem = NSMenuItem(
                        title: "Retomar Trabalho",
                        action: #selector(self.resumeWork),
                        keyEquivalent: ""
                    )
                    resumeItem.target = self
                    menu.addItem(resumeItem)
                } else {
                    let pauseItem = NSMenuItem(
                        title: "Pausar Trabalho",
                        action: #selector(self.pauseWork),
                        keyEquivalent: ""
                    )
                    pauseItem.target = self
                    menu.addItem(pauseItem)
                }
                
                let stopItem = NSMenuItem(
                    title: "Parar Trabalho",
                    action: #selector(self.stopWork),
                    keyEquivalent: ""
                )
                stopItem.target = self
                menu.addItem(stopItem)
            } else {
                let startItem = NSMenuItem(
                    title: "Iniciar Trabalho",
                    action: #selector(self.startWork),
                    keyEquivalent: ""
                )
                startItem.target = self
                menu.addItem(startItem)
            }

            // Abater tempo restante da jornada das horas extras (visível sempre que houver saldo e tempo restante)
            let todayStats = self.timeTracker.getTodayStats()
            let tempoTrabalhadoHoje = todayStats.totalTime
            let jornada = 6.0 * 3600.0
            let tempoRestante = max(0, jornada - tempoTrabalhadoHoje)
            let saldoExtras = self.timeTracker.getTotalOvertimeBalance()
            let podeAbater = (tempoRestante > 0) && (saldoExtras >= tempoRestante) && self.timeTracker.isWorking && !self.timeTracker.hasAbatedToday()
            let abaterItem = NSMenuItem(
                title: "Abater tempo restante da jornada das horas extras",
                action: podeAbater ? #selector(self.abaterTempoRestanteJornada) : nil,
                keyEquivalent: ""
            )
            abaterItem.target = self
            abaterItem.isEnabled = podeAbater
            if tempoRestante == 0 {
                abaterItem.toolTip = "Jornada já cumprida."
            } else if saldoExtras < tempoRestante {
                abaterItem.toolTip = "Saldo de horas extras insuficiente."
            } else if !self.timeTracker.isWorking {
                abaterItem.toolTip = "Só é possível abater durante uma jornada em andamento."
            }
            if saldoExtras > 0 {
                menu.addItem(abaterItem)
            }
            
            menu.addItem(NSMenuItem.separator())

            
            // Estatísticas do dia
            let todayItem = NSMenuItem()
            todayItem.title = "Hoje: \(self.formatDuration(todayStats.totalTime)) | Extras: \(self.formatDuration(todayStats.overtime))"
            todayItem.isEnabled = false
            menu.addItem(todayItem)
            
            // Estatísticas da semana
            let weekStats = self.timeTracker.getWeekStats()
            let weekItem = NSMenuItem()
            weekItem.title = "Semana: \(self.formatDuration(weekStats.totalTime)) | Extras: \(self.formatDuration(weekStats.overtime))"
            weekItem.isEnabled = false
            menu.addItem(weekItem)
            
            // Estatísticas do mês
            let monthStats = self.timeTracker.getMonthStats()
            let monthItem = NSMenuItem()
            monthItem.title = "Mês: \(self.formatDuration(monthStats.totalTime)) | Extras: \(self.formatDuration(monthStats.overtime))"
            monthItem.isEnabled = false
            menu.addItem(monthItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // Importar dados históricos (apenas se ainda não foi feito)
            if !self.timeTracker.hasImportedHistoricalOvertime() {
                let importItem = NSMenuItem(
                    title: "📥 Importar Horas Extras Históricas",
                    action: #selector(self.importHistoricalData),
                    keyEquivalent: ""
                )
                importItem.target = self
                menu.addItem(importItem)
                
                menu.addItem(NSMenuItem.separator())
            }
            
            // Usar horas extras
            if self.timeTracker.getTotalOvertimeBalance() > 0 {
                let useOvertimeItem = NSMenuItem(
                    title: "Usar 1h Extra (Saldo: \(self.formatDuration(self.timeTracker.getTotalOvertimeBalance())))",
                    action: #selector(self.useOvertime),
                    keyEquivalent: ""
                )
                useOvertimeItem.target = self
                menu.addItem(useOvertimeItem)
                
                menu.addItem(NSMenuItem.separator())
            }
            
            // Sair
            let quitItem = NSMenuItem(
                title: "Sair",
                action: #selector(self.quit),
                keyEquivalent: "q"
            )
            quitItem.target = self
            menu.addItem(quitItem)
            
            // Opção de reset (apenas para correção)
            let resetItem = NSMenuItem(
                title: "🔄 Reset Dados",
                action: #selector(self.resetData),
                keyEquivalent: ""
            )
            resetItem.target = self
            menu.addItem(resetItem)
            
            self.statusBarItem.menu = menu
        }
    }
    
    @objc private func statusBarButtonClicked() {
        // Atualizar o menu no momento do clique para garantir dados frescos
        updateMenu()
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
        NSApplication.shared.terminate(nil)
    }
    
    // Importar dados históricos de horas extras
    @objc func importHistoricalData() {
        timeTracker.importHistoricalOvertime()
        let alert = NSAlert()
        alert.messageText = "Dados Importados!"
        alert.informativeText = "Suas horas extras históricas foram importadas com sucesso:\n\n• Dia 28/7: 7h18\n• Dia 02/8: 4h20\n• Dia NN: 6h\n• Dia 07/8: 1h3\n• Dia 09/8: 4h\n• Dia 11/8: 2h48\n\nTotal: ~25,5 horas extras adicionadas ao seu saldo."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        updateMenu()
    }
    
    private func formatDuration(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // Abater automaticamente o tempo restante da jornada das horas extras
    @objc func abaterTempoRestanteJornada() {
        // Tempo já trabalhado hoje
        let todayStats = timeTracker.getTodayStats()
        let tempoTrabalhadoHoje = todayStats.totalTime
        let jornada = 6.0 * 3600.0
        let tempoRestante = max(0, jornada - tempoTrabalhadoHoje)
        let saldoExtras = timeTracker.getTotalOvertimeBalance()
        if tempoRestante == 0 {
            let alert = NSAlert()
            alert.messageText = "Jornada já cumprida"
            alert.informativeText = "Você já cumpriu sua jornada de trabalho de hoje."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        if saldoExtras < tempoRestante {
            let alert = NSAlert()
            alert.messageText = "Saldo insuficiente"
            alert.informativeText = "Você não possui horas extras suficientes para abater o tempo restante da jornada."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
    // Abater do saldo e encerrar jornada
    timeTracker.useOvertime(hours: tempoRestante / 3600.0)
    timeTracker.markAbatedToday(seconds: tempoRestante)
    timeTracker.stopWork()
    let alert = NSAlert()
    alert.messageText = "Jornada encerrada com horas extras!"
    alert.informativeText = String(format: "Foram abatidos %.2f horas extras para completar sua jornada de hoje.", tempoRestante / 3600.0)
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
    updateMenu()
    }
    
    // Sair do aplicativo
    @objc func quit() {
        if timeTracker.isWorking {
            timeTracker.stopWork()
        }
        NSApplication.shared.terminate(nil)
    }
    
    // Resetar todos os dados do aplicativo
    @objc func resetData() {
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
    
    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
