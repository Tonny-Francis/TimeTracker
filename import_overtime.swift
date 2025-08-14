#!/usr/bin/env swift

import Foundation

// Converter horas:minutos para horas decimais
func convertToDecimalHours(_ timeString: String) -> Double {
    let components = timeString.replacingOccurrences(of: "h", with: ":").components(separatedBy: ":")
    guard components.count >= 2,
          let hours = Double(components[0]),
          let minutes = Double(components[1]) else {
        // Se só tem horas (ex: "6h")
        if let hours = Double(timeString.replacingOccurrences(of: "h", with: "")) {
            return hours
        }
        return 0
    }
    return hours + (minutes / 60.0)
}

// Dados das horas extras
let overtimeData = [
    ("28", "7h18"),  // Assumindo julho
    ("02", "4h20"),  // Assumindo agosto
    ("NN", "6h"),    // Data genérica
    ("07", "1h3"),   // Assumindo agosto
    ("09", "4h"),    // Assumindo agosto
    ("11", "2h48")   // Assumindo agosto
]

// Criar datas aproximadas (assumindo 2025)
let calendar = Calendar.current
let currentYear = 2025

var totalHours: Double = 0

for (day, timeString) in overtimeData {
    let hours = convertToDecimalHours(timeString)
    totalHours += hours
    
    var dateString: String
    if day == "NN" {
        dateString = "Data não especificada"
    } else {
        // Assumir julho para dia 28, agosto para os outros
        let month = (day == "28") ? 7 : 8
        dateString = "\(day)/\(month)/\(currentYear)"
    }
    
    print("Dia \(day): \(timeString) = \(hours) horas (\(dateString))")
}

print("\nTotal de horas extras para importar: \(totalHours) horas")
print("\nPara importar essas horas, execute a aplicação e use a função de importação.")
