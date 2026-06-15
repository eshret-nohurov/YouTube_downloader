import SwiftUI

class SettingsViewModel: ObservableObject {
    @AppStorage("downloadFolder") var downloadFolderPath: String = ""
    @AppStorage("defaultQuality") var defaultQuality: String = "best"
    @AppStorage("cookiesMode") var cookiesMode: String = "browser"
    @AppStorage("cookiesBrowser") var cookiesBrowser: String = "chrome"
    @AppStorage("cookiesFilePath") var cookiesFilePath: String = ""

    var downloadFolder: URL {
        if !downloadFolderPath.isEmpty, FileManager.default.fileExists(atPath: downloadFolderPath) {
            return URL(fileURLWithPath: downloadFolderPath)
        }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }

    var cookiesFileDisplay: String {
        if cookiesFilePath.isEmpty {
            return "Не выбран"
        }
        return URL(fileURLWithPath: cookiesFilePath).lastPathComponent
    }

    var ytDlpVersion: String {
        guard let path = YtDlpService.shared.ytDlpPath else { return "Не установлен" }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Неизвестно"
        } catch {
            return "Ошибка"
        }
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Папка загрузки по умолчанию"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            downloadFolderPath = url.path
            UserDefaults.standard.set(url.path, forKey: "downloadFolder")
        }
    }

    func selectCookiesFile() {
        let panel = NSOpenPanel()
        panel.title = "Выберите файл cookies.txt"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText]

        if panel.runModal() == .OK, let url = panel.url {
            cookiesFilePath = url.path
        }
    }
}
