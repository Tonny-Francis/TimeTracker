import Foundation
import Combine

struct WorkSessionData: Codable {
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let pauseDuration: TimeInterval
    let isActive: Bool
}

struct OvertimeUsageData: Codable {
    let date: Date
    let hoursUsed: Double
    let reason: String
}

class TimeTracker: ObservableObject {
    private let lastAbateKey = "lastAbateDate"
        private let abateSecondsKey = "abateSecondsByDay"
    // Salva segundos abatidos para o dia (yyyy-MM-dd)
    private func saveAbateSeconds(_ seconds: TimeInterval, for date: Date) {
        var dict = userDefaults.dictionary(forKey: abateSecondsKey) as? [String: Double] ?? [:]
        let key = Self.dateKey(for: date)
        dict[key] = (dict[key] ?? 0) + seconds
        userDefaults.set(dict, forKey: abateSecondsKey)
    }

    // Recupera segundos abatidos para o dia (yyyy-MM-dd)
    private func getAbateSeconds(for date: Date) -> TimeInterval {
        let dict = userDefaults.dictionary(forKey: abateSecondsKey) as? [String: Double] ?? [:]
        let key = Self.dateKey(for: date)
        return dict[key] ?? 0
    }

    private static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    // Verifica se já houve abatimento hoje
    func hasAbatedToday() -> Bool {
        return getAbateSeconds(for: Date()) > 0
    }

    // Marca que houve abatimento hoje, registrando quantos segundos foram abatidos
    func markAbatedToday(seconds: TimeInterval) {
        saveAbateSeconds(seconds, for: Date())
    }
    static let shared = TimeTracker()
    
    @Published var isWorking = false
    @Published var isPaused = false
    @Published var currentSessionStart: Date?
    @Published var currentPauseStart: Date?
    @Published var totalPauseTime: TimeInterval = 0
    
    // Configurações do usuário (sem valores padrão hardcoded)
    var standardWorkHours: TimeInterval {
        get {
            let hours = userDefaults.double(forKey: "workHoursPerDay")
            return hours > 0 ? hours * 3600 : 8 * 3600 // Default 8h se não configurado
        }
        set {
            userDefaults.set(newValue / 3600, forKey: "workHoursPerDay")
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private var updateTimer: Timer?
    
    // Chave para verificar se é primeira execução
    private let firstLaunchKey = "hasLaunchedBefore"
    private let initialSetupCompletedKey = "initialSetupCompleted"
    
    private init() {
        // Verificar se há uma sessão em andamento
        checkForActiveSession()
        setupUpdateTimer()
    }
    
    // MARK: - Configuração Inicial
    
    /// Verifica se é a primeira vez que o usuário abre o app
    func isFirstLaunch() -> Bool {
        return !userDefaults.bool(forKey: firstLaunchKey)
    }
    
    /// Verifica se a configuração inicial foi completada
    func isInitialSetupCompleted() -> Bool {
        return userDefaults.bool(forKey: initialSetupCompletedKey)
    }
    
    /// Força uma nova configuração inicial (para debugging ou reset)
    func forceInitialSetup() {
        userDefaults.removeObject(forKey: firstLaunchKey)
        userDefaults.removeObject(forKey: initialSetupCompletedKey)
    }
    
    /// Marca que a configuração inicial foi completada
    func markInitialSetupCompleted() {
        userDefaults.set(true, forKey: firstLaunchKey)
        userDefaults.set(true, forKey: initialSetupCompletedKey)
    }
    
    /// Define as configurações iniciais do usuário
    func setupInitialConfiguration(workHoursPerDay: Double, initialOvertimeBalance: Double = 0, workDays: [Int] = [2, 3, 4, 5, 6]) {
        // Configurar horas de trabalho
        userDefaults.set(workHoursPerDay, forKey: "workHoursPerDay")
        
        // Configurar dias de trabalho
        setWorkDays(workDays)
        
        // Configurar saldo inicial de horas extras (se fornecido)
        if initialOvertimeBalance > 0 {
            setInitialOvertimeBalance(initialOvertimeBalance)
        }
        
        // Marcar configuração como completa
        markInitialSetupCompleted()
    }
    
    /// Define o saldo inicial de horas extras
    func setInitialOvertimeBalance(_ hours: Double) {
        userDefaults.set(hours, forKey: "initialOvertimeBalance")
        objectWillChange.send()
    }
    
    /// Obtém o saldo inicial de horas extras configurado
    func getInitialOvertimeBalance() -> Double {
        return userDefaults.double(forKey: "initialOvertimeBalance")
    }
    
    private func setupUpdateTimer() {
        // Timer para atualizar a interface quando estiver trabalhando
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isWorking {
                DispatchQueue.main.async {
                    // Força uma atualização da interface
                    self.objectWillChange.send()
                }
            }
        }
        RunLoop.main.add(updateTimer!, forMode: .common)
    }
    
    // MARK: - Configuração de Dias de Trabalho
    
    /// Define quais dias da semana são dias de trabalho
    func setWorkDays(_ workDays: [Int]) {
        userDefaults.set(workDays, forKey: "workDays")
        objectWillChange.send()
    }
    
    /// Retorna os dias da semana configurados como dias de trabalho
    /// Default: Segunda a Sexta (2, 3, 4, 5, 6)
    var workDays: [Int] {
        if let days = userDefaults.array(forKey: "workDays") as? [Int], !days.isEmpty {
            return days
        }
        return [2, 3, 4, 5, 6] // Segunda a Sexta como padrão
    }
    
    /// Verifica se um dia da semana é dia de trabalho
    func isWorkDay(_ weekday: Int) -> Bool {
        return workDays.contains(weekday)
    }
    
    /// Converte array de dias para string legível
    func workDaysDescription() -> String {
        let dayNames = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
        let workDayNames = workDays.sorted().map { dayNames[$0 - 1] }
        
        if workDayNames.count == 7 {
            return "Todos os dias"
        } else if workDayNames.count == 5 && workDays.contains(2) && workDays.contains(3) && workDays.contains(4) && workDays.contains(5) && workDays.contains(6) {
            return "Dias úteis (Seg-Sex)"
        } else if workDayNames.count <= 3 {
            return workDayNames.joined(separator: ", ")
        } else {
            return "\(workDayNames.prefix(2).joined(separator: ", ")) e mais \(workDayNames.count - 2)"
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveSessions(_ sessions: [WorkSessionData]) {
        if let data = try? JSONEncoder().encode(sessions) {
            userDefaults.set(data, forKey: "workSessions")
        }
    }
    
    private func loadSessions() -> [WorkSessionData] {
        guard let data = userDefaults.data(forKey: "workSessions"),
              let sessions = try? JSONDecoder().decode([WorkSessionData].self, from: data) else {
            return []
        }
        return sessions
    }
    
    private func saveOvertimeUsages(_ usages: [OvertimeUsageData]) {
        if let data = try? JSONEncoder().encode(usages) {
            userDefaults.set(data, forKey: "overtimeUsages")
        }
    }
    
    private func loadOvertimeUsages() -> [OvertimeUsageData] {
        guard let data = userDefaults.data(forKey: "overtimeUsages"),
              let usages = try? JSONDecoder().decode([OvertimeUsageData].self, from: data) else {
            return []
        }
        return usages
    }
    
    // MARK: - Work Session Management
    
    func startWork() {
        guard !isWorking else { return }
        
        isWorking = true
        isPaused = false
        currentSessionStart = Date()
        totalPauseTime = 0
        
        // Salvar estado ativo
        userDefaults.set(true, forKey: "isWorking")
        userDefaults.set(false, forKey: "isPaused")
        userDefaults.set(currentSessionStart, forKey: "currentSessionStart")
        userDefaults.set(0, forKey: "totalPauseTime")
        userDefaults.removeObject(forKey: "currentPauseStart")
        
        objectWillChange.send()
    }
    
    func pauseWork() {
        guard isWorking && !isPaused else { return }
        
        isPaused = true
        currentPauseStart = Date()
        
        // Salvar estado de pausa
        userDefaults.set(true, forKey: "isPaused")
        userDefaults.set(currentPauseStart, forKey: "currentPauseStart")
        
        objectWillChange.send()
    }
    
    func resumeWork() {
        guard isWorking && isPaused, let pauseStart = currentPauseStart else { return }
        
        // Calcular tempo de pausa
        let pauseDuration = Date().timeIntervalSince(pauseStart)
        totalPauseTime += pauseDuration
        
        isPaused = false
        currentPauseStart = nil
        
        // Salvar estado
        userDefaults.set(false, forKey: "isPaused")
        userDefaults.set(totalPauseTime, forKey: "totalPauseTime")
        userDefaults.removeObject(forKey: "currentPauseStart")
        
        objectWillChange.send()
    }
    
    func stopWork() {
        guard isWorking, let startTime = currentSessionStart else { return }
        
        let endTime = Date()
        var finalPauseTime = totalPauseTime
        
        // Se estava pausado, adicionar a pausa atual
        if isPaused, let pauseStart = currentPauseStart {
            finalPauseTime += endTime.timeIntervalSince(pauseStart)
        }
        
        isWorking = false
        isPaused = false
        
        // Criar sessão finalizada
        let session = WorkSessionData(
            startTime: startTime,
            endTime: endTime,
            duration: endTime.timeIntervalSince(startTime) - finalPauseTime,
            pauseDuration: finalPauseTime,
            isActive: false
        )
        
        // Salvar sessão
        var sessions = loadSessions()
        sessions.append(session)
        saveSessions(sessions)
        
        // Limpar estado ativo
        currentSessionStart = nil
        currentPauseStart = nil
        totalPauseTime = 0
        userDefaults.set(false, forKey: "isWorking")
        userDefaults.set(false, forKey: "isPaused")
        userDefaults.removeObject(forKey: "currentSessionStart")
        userDefaults.removeObject(forKey: "currentPauseStart")
        userDefaults.removeObject(forKey: "totalPauseTime")
        
        objectWillChange.send()
    }
    
    private func checkForActiveSession() {
        isWorking = userDefaults.bool(forKey: "isWorking")
        isPaused = userDefaults.bool(forKey: "isPaused")
        currentSessionStart = userDefaults.object(forKey: "currentSessionStart") as? Date
        currentPauseStart = userDefaults.object(forKey: "currentPauseStart") as? Date
        totalPauseTime = userDefaults.double(forKey: "totalPauseTime")
    }
    
    var currentSessionElapsed: TimeInterval {
        guard let startTime = currentSessionStart else { return 0 }
        let totalElapsed = Date().timeIntervalSince(startTime)
        var totalPausesDuration = totalPauseTime
        
        // Se está pausado, adicionar pausa atual
        if isPaused, let pauseStart = currentPauseStart {
            totalPausesDuration += Date().timeIntervalSince(pauseStart)
        }
        
        return max(0, totalElapsed - totalPausesDuration)
    }
    
    var currentPauseElapsed: TimeInterval {
        guard isPaused, let pauseStart = currentPauseStart else { return 0 }
        return Date().timeIntervalSince(pauseStart)
    }
    
    // MARK: - Statistics
    
    func getTodayStats() -> (totalTime: TimeInterval, overtime: TimeInterval) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return getStatsForPeriod(start: today, end: tomorrow)
    }
    
    func getWeekStats() -> (totalTime: TimeInterval, overtime: TimeInterval) {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        
        return getStatsForPeriod(start: weekStart, end: weekEnd)
    }
    
    func getMonthStats() -> (totalTime: TimeInterval, overtime: TimeInterval) {
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        
        return getStatsForPeriod(start: monthStart, end: monthEnd)
    }
    
    private func getStatsForPeriod(start: Date, end: Date) -> (totalTime: TimeInterval, overtime: TimeInterval) {
        let sessions = loadSessions()
        var totalTime: TimeInterval = 0
        
        for session in sessions {
            if session.startTime >= start && session.startTime < end && !session.isActive {
                totalTime += session.duration
            }
        }
        
        // Adicionar sessão atual se estiver ativa
        if isWorking && currentSessionStart! >= start && currentSessionStart! < end {
            totalTime += currentSessionElapsed
        }
        
        // Calcular horas extras baseado em dias úteis
        // Calcular horas extras baseado nos dias de trabalho configurados, descontando abatimentos
        let calendar = Calendar.current
        var expectedHours: TimeInterval = 0
        var currentDate = start
        while currentDate < end {
            let weekday = calendar.component(.weekday, from: currentDate)
            if isWorkDay(weekday) {
                let abate = getAbateSeconds(for: currentDate)
                expectedHours += max(0, standardWorkHours - abate)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
    let overtime = max(0, totalTime - expectedHours)
    return (totalTime, overtime)
    }
    
    private func getWorkDaysInPeriod(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        var workDays = 0
        var currentDate = start
        
        while currentDate < end {
            let weekday = calendar.component(.weekday, from: currentDate)
            if isWorkDay(weekday) {
                workDays += 1
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return workDays
    }
    
    // MARK: - Overtime Management
    
    private func getAllTimeStats() -> (totalTime: TimeInterval, overtime: TimeInterval) {
        let sessions = loadSessions()
        var totalTime: TimeInterval = 0
        
        for session in sessions {
            if !session.isActive {
                totalTime += session.duration
            }
        }
        
        // Adicionar sessão atual se estiver ativa
        if isWorking {
            totalTime += currentSessionElapsed
        }
        
        // Calcular horas extras considerando abatimentos desde a primeira sessão
        if let firstSession = sessions.first {
            return getStatsForPeriod(start: firstSession.startTime, end: Date())
        }
        
        return (totalTime, 0)
    }
    
    func useOvertime(hours: Double) {
        let usage = OvertimeUsageData(
            date: Date(),
            hoursUsed: hours,
            reason: "Utilização de hora extra"
        )
        
        var usages = loadOvertimeUsages()
        usages.append(usage)
        saveOvertimeUsages(usages)
        
        objectWillChange.send()
    }
    
    func getTotalOvertimeBalance() -> TimeInterval {
        let usages = loadOvertimeUsages()
        let totalUsed = usages.reduce(0) { $0 + $1.hoursUsed }
        
        // Calcular horas extras das sessões atuais
        let allTimeStats = getAllTimeStats()
        let currentOvertime = allTimeStats.overtime
        
        // Adicionar saldo inicial configurado pelo usuário
        let initialBalance = userDefaults.double(forKey: "initialOvertimeBalance")
        
        // Total = horas extras atuais + saldo inicial - horas usadas
        let totalBalance = (currentOvertime / 3600) + initialBalance - totalUsed
        
        return max(0, totalBalance * 3600) // Converter para segundos
    }
    
    // MARK: - Reset Data (for debugging)
    
    func resetAllData() {
        userDefaults.removeObject(forKey: "workSessions")
        userDefaults.removeObject(forKey: "overtimeUsages")
        userDefaults.removeObject(forKey: "initialOvertimeBalance")
        userDefaults.removeObject(forKey: "standardWorkHours")
        userDefaults.removeObject(forKey: "workDays")
        userDefaults.removeObject(forKey: "isWorking")
        userDefaults.removeObject(forKey: "isPaused")
        userDefaults.removeObject(forKey: "currentSessionStart")
        userDefaults.removeObject(forKey: "currentPauseStart")
        userDefaults.removeObject(forKey: "totalPauseTime")
        userDefaults.removeObject(forKey: firstLaunchKey)
        userDefaults.removeObject(forKey: initialSetupCompletedKey)
        userDefaults.removeObject(forKey: lastAbateKey)
        userDefaults.removeObject(forKey: abateSecondsKey)
        
        isWorking = false
        isPaused = false
        currentSessionStart = nil
        currentPauseStart = nil
        totalPauseTime = 0
        
        objectWillChange.send()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}
