import Foundation
import os.log

enum LogLevel: String, CaseIterable {
    case info = "ИНФО"
    case warning = "ВНИМАНИЕ"
    case error = "ОШИБКА"
    case debug = "ОТЛАДКА"

    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        case .debug: return "ladybug"
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let details: String?

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var fullTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var formattedEntry: String {
        var str = "[\(fullTimestamp)] [\(level.rawValue)] [\(category)] \(message)"
        if let details = details {
            str += " | \(details)"
        }
        return str
    }
}

class TelemetryService: ObservableObject {
    static let shared = TelemetryService()

    @Published var entries: [LogEntry] = []
    @Published var filterLevel: LogLevel? = nil

    var filteredEntries: [LogEntry] {
        if let level = filterLevel {
            return entries.filter { $0.level == level }
        }
        return entries
    }

    private let logger = Logger(subsystem: "com.eshret.yt-downloader", category: "Telemetry")
    private let logFileURL: URL
    private let queue = DispatchQueue(label: "com.youtubeloader.telemetry", qos: .utility)

    private init() {
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/YouTubeLoader")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = "log_\(formatter.string(from: Date())).txt"
        logFileURL = logsDir.appendingPathComponent(fileName)

        log(.info, category: "Система", message: "Приложение запущено")
    }

    func log(_ level: LogLevel, category: String, message: String, details: String? = nil) {
        let entry = LogEntry(timestamp: Date(), level: level, category: category, message: message, details: details)

        DispatchQueue.main.async {
            self.entries.append(entry)
            if self.entries.count > 5000 {
                self.entries.removeFirst(self.entries.count - 5000)
            }
        }

        queue.async { [weak self] in
            self?.writeToFile(entry)
        }

        switch level {
        case .info: logger.info("\(entry.formattedEntry)")
        case .warning: logger.warning("\(entry.formattedEntry)")
        case .error: logger.error("\(entry.formattedEntry)")
        case .debug: logger.debug("\(entry.formattedEntry)")
        }
    }

    private func writeToFile(_ entry: LogEntry) {
        let line = entry.formattedEntry + "\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logFileURL)
        }
    }

    var logFileLocation: URL { logFileURL }

    func clearLogs() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
        queue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.logFileURL)
        }
        log(.info, category: "Система", message: "Журнал очищен")
    }
}
