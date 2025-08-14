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
    static let shared = TimeTracker()
    
    @Published var isWorking = false
    @Published var isPaused = false
    @Published var currentSessionStart: Date?
    @Published var currentPauseStart: Date?
    @Published var totalPauseTime: TimeInterval = 0
    
    private let standardWorkHours: TimeInterval = 6 * 3600 // 6 horas em segundos
    private let userDefaults = UserDefaults.standard
    
    private init() {
        // Verificar se há uma sessão em andamento
        checkForActiveSession()
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
        let workDays = getWorkDaysInPeriod(start: start, end: end)
        let expectedHours = TimeInterval(workDays) * standardWorkHours
        let overtime = max(0, totalTime - expectedHours)
        
        return (totalTime, overtime)
    }
    
    private func getWorkDaysInPeriod(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        var workDays = 0
        var currentDate = start
        
        while currentDate < end {
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday >= 2 && weekday <= 6 { // Segunda a sexta
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
        
        // Estimar dias de trabalho desde a primeira sessão
        if let firstSession = sessions.first {
            let workDays = getWorkDaysInPeriod(start: firstSession.startTime, end: Date())
            let expectedHours = TimeInterval(workDays) * standardWorkHours
            let overtime = max(0, totalTime - expectedHours)
            return (totalTime, overtime)
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
    
    // MARK: - Import Historical Overtime
    
    func importHistoricalOvertime() {
        // Total de horas extras calculadas do seu bloco de notas
        let totalHistoricalOvertime = 25.48 // 7.3 + 4.33 + 6.0 + 1.05 + 4.0 + 2.8
        
        // Salvar diretamente como saldo de horas extras
        let currentBalance = userDefaults.double(forKey: "historicalOvertimeBalance")
        userDefaults.set(currentBalance + totalHistoricalOvertime, forKey: "historicalOvertimeBalance")
        
        // Marcar que a importação foi feita
        userDefaults.set(true, forKey: "historicalOvertimeImported")
        
        objectWillChange.send()
    }
    
    func getTotalOvertimeBalance() -> TimeInterval {
        let usages = loadOvertimeUsages()
        let totalUsed = usages.reduce(0) { $0 + $1.hoursUsed }
        
        // Calcular horas extras das sessões atuais
        let allTimeStats = getAllTimeStats()
        let currentOvertime = allTimeStats.overtime
        
        // Adicionar saldo histórico importado
        let historicalBalance = userDefaults.double(forKey: "historicalOvertimeBalance")
        
        // Total = horas extras atuais + histórico - horas usadas
        let totalBalance = (currentOvertime / 3600) + historicalBalance - totalUsed
        
        return max(0, totalBalance * 3600) // Converter para segundos
    }
    
    func hasImportedHistoricalOvertime() -> Bool {
        return userDefaults.bool(forKey: "historicalOvertimeImported")
    }
    
    // MARK: - Reset Data (for debugging)
    
    func resetAllData() {
        userDefaults.removeObject(forKey: "workSessions")
        userDefaults.removeObject(forKey: "overtimeUsages")
        userDefaults.removeObject(forKey: "historicalOvertimeBalance")
        userDefaults.removeObject(forKey: "historicalOvertimeImported")
        userDefaults.removeObject(forKey: "isWorking")
        userDefaults.removeObject(forKey: "isPaused")
        userDefaults.removeObject(forKey: "currentSessionStart")
        userDefaults.removeObject(forKey: "currentPauseStart")
        userDefaults.removeObject(forKey: "totalPauseTime")
        
        isWorking = false
        isPaused = false
        currentSessionStart = nil
        currentPauseStart = nil
        totalPauseTime = 0
        
        objectWillChange.send()
    }
}
