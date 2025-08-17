import Cocoa
import Combine

class MenuBarController: ObservableObject {
    private let statusBarItem: NSStatusItem
    private let timeTracker: TimeTracker
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.timeTracker = TimeTracker.shared
        
        setupStatusBarItem()
        setupTimer()
        setupBindings()
        updateStatusBarTitle()
        setupMenu()
        
        // Executar verificação inicial após um delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showInitialSetupIfNeeded()
        }
    }
    
    private func setupStatusBarItem() {
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Routine Timer")
            button.image?.isTemplate = true
        }
        statusBarItem.isVisible = true
    }
    
    private func setupTimer() {
        // Timer para atualizar a interface a cada segundo
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusBarTitle()
                self?.updateMenuContent()
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let button = self.statusBarItem.button {
                // Atualizar apenas o ícone baseado no estado
                if self.timeTracker.isWorking {
                    if self.timeTracker.isPaused {
                        // Ícone de pausa
                        button.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Em Pausa")
                    } else {
                        // Ícone de trabalho ativo
                        button.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Trabalhando")
                    }
                } else {
                    // Ícone padrão quando não está trabalhando
                    button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Parado")
                }
                
                // Garantir que continue visível
                self.statusBarItem.isVisible = true
            }
        }
    }
    
    private func updateMenuContent() {
        guard let menu = statusBarItem.menu, menu.items.count > 0 else { return }
        
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
        
        // Atualizar estatísticas dinâmicas
        for item in menu.items {
            if item.title.hasPrefix("📅 Hoje:") {
                let todayStats = timeTracker.getTodayStats()
                item.title = "📅 Hoje: \(formatDuration(todayStats.totalTime)) | Extras: \(formatDuration(todayStats.overtime))"
            } else if item.title.hasPrefix("📊 Semana:") {
                let weekStats = timeTracker.getWeekStats()
                item.title = "📊 Semana: \(formatDuration(weekStats.totalTime)) | Extras: \(formatDuration(weekStats.overtime))"
            } else if item.title.hasPrefix("📈 Mês:") {
                let monthStats = timeTracker.getMonthStats()
                item.title = "📈 Mês: \(formatDuration(monthStats.totalTime)) | Extras: \(formatDuration(monthStats.overtime))"
            } else if item.title.contains("Saldo:") {
                let balance = timeTracker.getTotalOvertimeBalance()
                item.title = "💰 Saldo: \(formatDuration(balance))"
            }
        }
    }
    
    private func setupMenu() {
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
                    title: "▶️ Retomar Trabalho",
                    action: #selector(self.resumeWork),
                    keyEquivalent: ""
                )
                resumeItem.target = self
                menu.addItem(resumeItem)
            } else {
                let pauseItem = NSMenuItem(
                    title: "⏸️ Pausar Trabalho",
                    action: #selector(self.pauseWork),
                    keyEquivalent: ""
                )
                pauseItem.target = self
                menu.addItem(pauseItem)
            }
            
            let stopItem = NSMenuItem(
                title: "⏹️ Parar Trabalho",
                action: #selector(self.stopWork),
                keyEquivalent: ""
            )
            stopItem.target = self
            menu.addItem(stopItem)
        } else {
            let startItem = NSMenuItem(
                title: "▶️ Iniciar Trabalho",
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
            title: "⚡ Abater Horas Extras",
            action: podeAbater ? #selector(self.abaterTempoRestanteJornada) : nil,
            keyEquivalent: ""
        )
        abaterItem.target = self
        abaterItem.isEnabled = podeAbater
        if tempoRestante == 0 {
            abaterItem.toolTip = "Jornada já foi completada hoje."
        } else if saldoExtras < tempoRestante {
            abaterItem.toolTip = "Saldo de horas extras insuficiente."
        } else if !self.timeTracker.isWorking {
            abaterItem.toolTip = "Só é possível abater durante uma jornada em andamento."
        }
        menu.addItem(abaterItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Estatísticas do dia
        let todayItem = NSMenuItem()
        todayItem.title = "📅 Hoje: \(self.formatDuration(todayStats.totalTime)) | Extras: \(self.formatDuration(todayStats.overtime))"
        todayItem.isEnabled = false
        menu.addItem(todayItem)
        
        // Estatísticas da semana
        let weekStats = self.timeTracker.getWeekStats()
        let weekItem = NSMenuItem()
        weekItem.title = "📊 Semana: \(self.formatDuration(weekStats.totalTime)) | Extras: \(self.formatDuration(weekStats.overtime))"
        weekItem.isEnabled = false
        menu.addItem(weekItem)
        
        // Estatísticas do mês
        let monthStats = self.timeTracker.getMonthStats()
        let monthItem = NSMenuItem()
        monthItem.title = "📈 Mês: \(self.formatDuration(monthStats.totalTime)) | Extras: \(self.formatDuration(monthStats.overtime))"
        monthItem.isEnabled = false
        menu.addItem(monthItem)
        
        // Saldo de horas extras
        let balance = self.timeTracker.getTotalOvertimeBalance()
        let balanceItem = NSMenuItem()
        balanceItem.title = "💰 Saldo: \(self.formatDuration(balance))"
        balanceItem.isEnabled = false
        menu.addItem(balanceItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Configurações
        let configMenuItem = NSMenuItem(title: "⚙️ Configurações", action: #selector(self.showConfigurationsModal), keyEquivalent: "")
        configMenuItem.target = self
        menu.addItem(configMenuItem)

        menu.addItem(NSMenuItem.separator())
        
        // Sair
        let quitItem = NSMenuItem(
            title: "🚪 Sair",
            action: #selector(self.quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        self.statusBarItem.menu = menu
    }
    
    func updateMenu() {
        setupMenu()
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
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600)) / 60
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        
        return String(format: "%02dh %02dm %02ds", hours, minutes, remainingSeconds)
    }
    
    @objc func abaterTempoRestanteJornada() {
        // Tempo já trabalhado hoje
        let todayStats = timeTracker.getTodayStats()
        let tempoTrabalhadoHoje = todayStats.totalTime
        let jornada = 6.0 * 3600.0
        let tempoRestante = max(0, jornada - tempoTrabalhadoHoje)
        let saldoExtras = timeTracker.getTotalOvertimeBalance()
        if tempoRestante == 0 {
            let alert = NSAlert()
            alert.messageText = "Jornada já foi completada hoje!"
            alert.informativeText = "Você já trabalhou suas 6 horas obrigatórias."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        if saldoExtras < tempoRestante {
            let alert = NSAlert()
            alert.messageText = "Saldo de horas extras insuficiente!"
            alert.informativeText = "Você possui \(formatDuration(saldoExtras)) de saldo, mas precisa de \(formatDuration(tempoRestante)) para completar a jornada."
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
        alert.informativeText = "Foram utilizadas \(formatDuration(tempoRestante)) do seu banco de horas extras para completar a jornada de hoje."
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
    
    // MARK: - HH:MM Conversion Functions
    
    private func hoursToHHMM(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "%02d:%02d", h, m)
    }
    
    private func hhmmToHours(_ hhmmString: String) -> Double? {
        let components = hhmmString.components(separatedBy: ":")
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]),
              hours >= 0, 
              minutes >= 0, minutes < 60 else {
            return nil
        }
        return Double(hours) + Double(minutes) / 60.0
    }
    
    // MARK: - Initial Setup
    
    private func showInitialSetupIfNeeded() {
        // Executar após um pequeno delay para garantir que a interface esteja pronta
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let isFirstLaunch = self.timeTracker.isFirstLaunch()
            let isSetupCompleted = self.timeTracker.isInitialSetupCompleted()
            
            if isFirstLaunch || !isSetupCompleted {
                self.showInitialSetup()
            }
        }
    }
    
    private func showInitialSetup() {
        let alert = NSAlert()
        alert.messageText = "🎯 Bem-vindo ao Routine!"
        alert.informativeText = "Configure sua jornada de trabalho para começar.\n\nDeseja usar a configuração padrão (8h por dia, segunda a sexta) ou personalizar?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Personalizar")
        alert.addButton(withTitle: "Usar Padrão")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Usuário escolheu personalizar
            showWorkHoursSetup()
        } else {
            // Usar configurações padrão: 8h de trabalho, sem horas extras
            timeTracker.setupInitialConfiguration(workHoursPerDay: 8.0, initialOvertimeBalance: 0.0)
            showWelcomeMessage()
        }
    }
    
    private func showWorkHoursSetup() {
        let alert = NSAlert()
        alert.messageText = "⏰ Configurar Jornada de Trabalho"
        alert.informativeText = "Quantas horas você trabalha por dia?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continuar")
        alert.addButton(withTitle: "Cancelar")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 150, height: 24))
        textField.stringValue = "08:00"
        textField.placeholderString = "Ex: 08:00"
        alert.accessoryView = textField
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let timeText = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let workHours = hhmmToHours(timeText), workHours > 0 {
                showOvertimeBalanceSetup(workHours: workHours)
            } else {
                showErrorAlert(message: "Por favor, digite um horário válido no formato HH:MM (ex: 08:00)")
                showWorkHoursSetup()
            }
        } else {
            // Usuário cancelou, usar padrão
            timeTracker.setupInitialConfiguration(workHoursPerDay: 8.0, initialOvertimeBalance: 0.0)
            showWelcomeMessage()
        }
    }
    
    private func showOvertimeBalanceSetup(workHours: Double) {
        let alert = NSAlert()
        alert.messageText = "💰 Banco de Horas Inicial"
        alert.informativeText = "Você possui algum saldo de horas extras?\n(Digite 00:00 se não tiver saldo)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continuar")
        alert.addButton(withTitle: "Cancelar")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 150, height: 24))
        textField.stringValue = "00:00"
        textField.placeholderString = "Ex: 10:30"
        alert.accessoryView = textField
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let timeText = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let overtimeBalance = hhmmToHours(timeText), overtimeBalance >= 0 {
                showWorkDaysSetup(workHours: workHours, overtimeBalance: overtimeBalance)
            } else {
                showErrorAlert(message: "Por favor, digite um horário válido no formato HH:MM (ex: 10:30)")
                showOvertimeBalanceSetup(workHours: workHours)
            }
        } else {
            // Usuário cancelou, usar padrão
            timeTracker.setupInitialConfiguration(workHoursPerDay: 8.0, initialOvertimeBalance: 0.0)
            showWelcomeMessage()
        }
    }
    
    private func showWorkDaysSetup(workHours: Double, overtimeBalance: Double) {
        let alert = NSAlert()
        alert.messageText = "📅 Dias de Trabalho"
        alert.informativeText = "Selecione os dias da semana em que você trabalha:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Finalizar")
        alert.addButton(withTitle: "Cancelar")
        
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        
        let dayNames = ["Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"]
        var checkboxes: [NSButton] = []
        
        for (index, dayName) in dayNames.enumerated() {
            let checkbox = NSButton(checkboxWithTitle: dayName, target: nil, action: nil)
            let row = index % 4
            let col = index / 4
            checkbox.frame = NSRect(x: col * 150, y: 90 - (row * 25), width: 140, height: 20)
            
            // Marcar segunda a sexta como padrão
            if index >= 1 && index <= 5 {
                checkbox.state = .on
            }
            
            containerView.addSubview(checkbox)
            checkboxes.append(checkbox)
        }
        
        alert.accessoryView = containerView
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let selectedDays = checkboxes.enumerated().compactMap { index, checkbox in
                checkbox.state == .on ? index + 1 : nil // +1 porque weekday começa em 1
            }
            
            if selectedDays.isEmpty {
                showErrorAlert(message: "Selecione pelo menos um dia de trabalho.")
                showWorkDaysSetup(workHours: workHours, overtimeBalance: overtimeBalance)
            } else {
                // Salvar configurações
                timeTracker.setupInitialConfiguration(workHoursPerDay: workHours, initialOvertimeBalance: overtimeBalance, workDays: selectedDays)
                showWelcomeMessage()
            }
        } else {
            // Usuário cancelou, usar padrão
            timeTracker.setupInitialConfiguration(workHoursPerDay: 8.0, initialOvertimeBalance: 0.0)
            showWelcomeMessage()
        }
    }
    
    private func showWelcomeMessage() {
        let alert = NSAlert()
        alert.messageText = "✅ Configuração Concluída!"
        alert.informativeText = "O Routine está pronto para uso. Você pode acessar as configurações a qualquer momento através do menu."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Começar")
        alert.runModal()
        
        updateMenu()
    }
    
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "❌ Erro"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Configuration Methods
    
    @objc private func showConfigurationsModal() {
        let alert = NSAlert()
        alert.messageText = "⚙️ Configurações do Routine"
        alert.informativeText = "Personalize sua jornada de trabalho"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "💾 Salvar")
        alert.addButton(withTitle: "❌ Cancelar")
        
        // Container principal
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 280))
        
        // ===== SEÇÃO 1: JORNADA DE TRABALHO =====
        // Título da seção
        let workSectionTitle = NSTextField(labelWithString: "🕒 JORNADA DE TRABALHO")
        workSectionTitle.font = NSFont.boldSystemFont(ofSize: 13)
        workSectionTitle.frame = NSRect(x: 20, y: 250, width: 200, height: 20)
        containerView.addSubview(workSectionTitle)
        
        // Linha separadora
        let workSeparator = NSBox()
        workSeparator.boxType = .separator
        workSeparator.frame = NSRect(x: 20, y: 245, width: 440, height: 1)
        containerView.addSubview(workSeparator)
        
        // Campo de jornada diária
        let workHoursLabel = NSTextField(labelWithString: "Horas por dia:")
        workHoursLabel.frame = NSRect(x: 30, y: 215, width: 100, height: 17)
        containerView.addSubview(workHoursLabel)
        
        let workHoursField = NSTextField(frame: NSRect(x: 140, y: 212, width: 80, height: 24))
        let currentHours = timeTracker.standardWorkHours / 3600.0
        workHoursField.stringValue = hoursToHHMM(currentHours)
        workHoursField.placeholderString = "08:00"
        workHoursField.alignment = .center
        containerView.addSubview(workHoursField)
        
        let workHoursHint = NSTextField(labelWithString: "(formato HH:MM)")
        workHoursHint.font = NSFont.systemFont(ofSize: 10)
        workHoursHint.textColor = .secondaryLabelColor
        workHoursHint.frame = NSRect(x: 230, y: 218, width: 100, height: 12)
        containerView.addSubview(workHoursHint)
        
        // ===== SEÇÃO 2: BANCO DE HORAS =====
        // Título da seção
        let overtimeSectionTitle = NSTextField(labelWithString: "💰 BANCO DE HORAS")
        overtimeSectionTitle.font = NSFont.boldSystemFont(ofSize: 13)
        overtimeSectionTitle.frame = NSRect(x: 20, y: 180, width: 200, height: 20)
        containerView.addSubview(overtimeSectionTitle)
        
        // Linha separadora
        let overtimeSeparator = NSBox()
        overtimeSeparator.boxType = .separator
        overtimeSeparator.frame = NSRect(x: 20, y: 175, width: 440, height: 1)
        containerView.addSubview(overtimeSeparator)
        
        // Campo de banco de horas
        let overtimeLabel = NSTextField(labelWithString: "Saldo inicial:")
        overtimeLabel.frame = NSRect(x: 30, y: 145, width: 100, height: 17)
        containerView.addSubview(overtimeLabel)
        
        let overtimeField = NSTextField(frame: NSRect(x: 140, y: 142, width: 80, height: 24))
        let currentBalance = timeTracker.getInitialOvertimeBalance()
        overtimeField.stringValue = hoursToHHMM(currentBalance)
        overtimeField.placeholderString = "00:00"
        overtimeField.alignment = .center
        containerView.addSubview(overtimeField)
        
        let overtimeHint = NSTextField(labelWithString: "(formato HH:MM)")
        overtimeHint.font = NSFont.systemFont(ofSize: 10)
        overtimeHint.textColor = .secondaryLabelColor
        overtimeHint.frame = NSRect(x: 230, y: 148, width: 100, height: 12)
        containerView.addSubview(overtimeHint)
        
        // ===== SEÇÃO 3: DIAS DE TRABALHO =====
        // Título da seção
        let daysSectionTitle = NSTextField(labelWithString: "📅 DIAS DE TRABALHO")
        daysSectionTitle.font = NSFont.boldSystemFont(ofSize: 13)
        daysSectionTitle.frame = NSRect(x: 20, y: 110, width: 200, height: 20)
        containerView.addSubview(daysSectionTitle)
        
        // Linha separadora
        let daysSeparator = NSBox()
        daysSeparator.boxType = .separator
        daysSeparator.frame = NSRect(x: 20, y: 105, width: 440, height: 1)
        containerView.addSubview(daysSeparator)
        
        // Checkboxes para dias da semana em layout mais organizado
        let dayNames = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
        let currentWorkDays = timeTracker.workDays
        var dayCheckboxes: [NSButton] = []
        
        // Container para os checkboxes
        let checkboxContainer = NSView(frame: NSRect(x: 30, y: 60, width: 420, height: 40))
        containerView.addSubview(checkboxContainer)
        
        for (index, dayName) in dayNames.enumerated() {
            let checkbox = NSButton(checkboxWithTitle: dayName, target: nil, action: nil)
            checkbox.frame = NSRect(x: index * 58, y: 10, width: 55, height: 20)
            checkbox.font = NSFont.systemFont(ofSize: 11)
            
            if currentWorkDays.contains(index + 1) {
                checkbox.state = .on
            }
            
            checkboxContainer.addSubview(checkbox)
            dayCheckboxes.append(checkbox)
        }
        
        alert.accessoryView = containerView
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            var hasErrors = false
            var errorMessage = "Corrija os seguintes erros:\n"
            
            // Validar e aplicar jornada de trabalho
            let workText = workHoursField.stringValue
            if let workHours = hhmmToHours(workText), workHours > 0 {
                timeTracker.standardWorkHours = workHours * 3600.0
            } else {
                hasErrors = true
                errorMessage += "• Jornada diária deve ser um horário válido (ex: 08:00)\n"
            }
            
            // Validar e aplicar banco de horas
            let overtimeText = overtimeField.stringValue
            if let overtime = hhmmToHours(overtimeText), overtime >= 0 {
                timeTracker.setInitialOvertimeBalance(overtime)
            } else {
                hasErrors = true
                errorMessage += "• Banco de horas deve ser um horário válido (ex: 10:30)\n"
            }
            
            // Validar e aplicar dias de trabalho
            let selectedDays = dayCheckboxes.enumerated().compactMap { index, checkbox in
                checkbox.state == .on ? index + 1 : nil
            }
            
            if selectedDays.isEmpty {
                hasErrors = true
                errorMessage += "• Selecione pelo menos um dia de trabalho\n"
            } else {
                timeTracker.setWorkDays(selectedDays)
            }
            
            if hasErrors {
                showErrorAlert(message: errorMessage)
                showConfigurationsModal() // Reabrir modal
            } else {
                updateMenu()
                
                // Marcar que o usuário interveio/configurou algo após o reset
                timeTracker.markInitialSetupCompleted()
                
                let successAlert = NSAlert()
                successAlert.messageText = "✅ Configurações Salvas"
                successAlert.informativeText = "Todas as configurações foram atualizadas com sucesso!"
                successAlert.alertStyle = .informational
                successAlert.addButton(withTitle: "OK")
                successAlert.runModal()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
