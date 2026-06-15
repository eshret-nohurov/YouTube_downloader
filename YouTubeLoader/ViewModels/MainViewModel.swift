import SwiftUI

@MainActor
class MainViewModel: ObservableObject {
    @Published var urlText: String = ""
    @Published var videoInfo: VideoInfo?
    @Published var selectedFormat: VideoFormat?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var downloadFolder: URL
    @Published var showLogs: Bool = false

    private let ytDlpService = YtDlpService.shared

    init() {
        if let savedPath = UserDefaults.standard.string(forKey: "downloadFolder"),
           FileManager.default.fileExists(atPath: savedPath) {
            downloadFolder = URL(fileURLWithPath: savedPath)
        } else {
            downloadFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
    }

    var isYtDlpAvailable: Bool { ytDlpService.isAvailable }
    var isFfmpegAvailable: Bool { ytDlpService.isFfmpegAvailable }

    func pasteFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string) {
            urlText = str.trimmingCharacters(in: .whitespacesAndNewlines)
            TelemetryService.shared.log(.debug, category: "UI", message: "Вставлено из буфера обмена")
            // Автозапуск поиска при вставке YouTube ссылки
            if urlText.contains("youtube.com") || urlText.contains("youtu.be") {
                fetchVideoInfo()
            }
        }
    }

    func fetchVideoInfo() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errorMessage = "Введите ссылку на видео"
            return
        }

        guard trimmed.contains("youtube.com") || trimmed.contains("youtu.be") else {
            errorMessage = "Поддерживаются только ссылки YouTube"
            return
        }

        isLoading = true
        errorMessage = nil
        videoInfo = nil
        selectedFormat = nil

        TelemetryService.shared.log(.info, category: "UI", message: "Запрос информации", details: trimmed)

        Task {
            do {
                let info = try await ytDlpService.getVideoInfo(url: trimmed)
                self.videoInfo = info
                // Применяем качество из настроек
                let defaultQ = UserDefaults.standard.string(forKey: "defaultQuality") ?? "best"
                self.selectedFormat = info.availableFormats.first(where: { $0.id == defaultQ })
                    ?? info.availableFormats.first
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                TelemetryService.shared.log(.error, category: "UI", message: "Ошибка получения информации", details: error.localizedDescription)
            }
        }
    }

    func selectDownloadFolder() {
        let panel = NSOpenPanel()
        panel.title = "Выберите папку для загрузки"
        panel.message = "Скачанные видео будут сохранены в выбранную папку"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            downloadFolder = url
            UserDefaults.standard.set(url.path, forKey: "downloadFolder")
            TelemetryService.shared.log(.info, category: "UI", message: "Папка загрузки изменена", details: url.path)
        }
    }

    func startDownload(manager: DownloadManager) {
        guard let videoInfo = videoInfo, let format = selectedFormat else { return }
        manager.addDownload(videoInfo: videoInfo, format: format, destination: downloadFolder)

        TelemetryService.shared.log(.info, category: "UI",
            message: "Загрузка запущена",
            details: "\(videoInfo.title) | \(format.quality)")

        self.videoInfo = nil
        self.urlText = ""
        self.selectedFormat = nil
        self.errorMessage = nil
    }

    func clearForm() {
        urlText = ""
        videoInfo = nil
        selectedFormat = nil
        errorMessage = nil
        isLoading = false
    }

    func cancelFetch() {
        ytDlpService.cancelInfoFetch()
        isLoading = false
        errorMessage = nil
    }

    func refreshDependencies() {
        ytDlpService.refreshPaths()
        objectWillChange.send()
    }
}
