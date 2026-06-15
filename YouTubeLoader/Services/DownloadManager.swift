import Foundation
import AppKit

class DownloadManager: ObservableObject {
    @Published var tasks: [DownloadTask] = []

    private let ytDlpService = YtDlpService.shared

    var activeTasks: [DownloadTask] {
        tasks.filter { $0.status == .downloading || $0.status == .waiting || $0.status == .merging }
    }

    var completedTasks: [DownloadTask] {
        tasks.filter { $0.status == .completed }
    }

    var failedTasks: [DownloadTask] {
        tasks.filter { $0.status == .failed || $0.status == .cancelled }
    }

    func addDownload(videoInfo: VideoInfo, format: VideoFormat, destination: URL) {
        let task = DownloadTask(
            videoTitle: videoInfo.title,
            quality: format.quality,
            destinationURL: destination,
            url: videoInfo.url,
            formatString: format.formatString,
            isAudioOnly: format.isAudioOnly
        )

        tasks.insert(task, at: 0)
        TelemetryService.shared.log(.info, category: "Менеджер",
            message: "Добавлена загрузка",
            details: "\(videoInfo.title) | \(format.quality)")

        Task {
            do {
                try await ytDlpService.download(task: task)
            } catch {
                await MainActor.run {
                    if task.status != .cancelled {
                        task.status = .failed
                        if task.errorMessage == nil {
                            task.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
    }

    func cancelDownload(_ task: DownloadTask) {
        task.status = .cancelled
        task.process?.terminate()
        TelemetryService.shared.log(.info, category: "Менеджер", message: "Отменена загрузка: \(task.videoTitle)")
    }

    func removeDownload(_ task: DownloadTask) {
        if task.status == .downloading || task.status == .waiting || task.status == .merging {
            cancelDownload(task)
        }
        tasks.removeAll { $0.id == task.id }
        TelemetryService.shared.log(.debug, category: "Менеджер", message: "Удалена из списка: \(task.videoTitle)")
    }

    func clearCompleted() {
        let count = tasks.filter { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }.count
        tasks.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
        TelemetryService.shared.log(.info, category: "Менеджер", message: "Очищено завершённых: \(count)")
    }

    func retryDownload(_ task: DownloadTask) {
        task.status = .waiting
        task.progress = 0
        task.speed = ""
        task.eta = ""
        task.errorMessage = nil
        task.filePath = nil

        TelemetryService.shared.log(.info, category: "Менеджер", message: "Повтор загрузки: \(task.videoTitle)")

        Task {
            do {
                try await ytDlpService.download(task: task)
            } catch {
                await MainActor.run {
                    if task.status != .cancelled {
                        task.status = .failed
                        if task.errorMessage == nil {
                            task.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
    }

    func playFile(_ task: DownloadTask) {
        if let path = task.filePath, FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } else {
            // Ищем файл в папке загрузки
            if let file = findDownloadedFile(task) {
                NSWorkspace.shared.open(file)
            }
        }
    }

    func openInFinder(_ task: DownloadTask) {
        if let path = task.filePath, FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        } else if let file = findDownloadedFile(task) {
            NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
        } else {
            NSWorkspace.shared.open(task.destinationURL)
        }
    }

    private func findDownloadedFile(_ task: DownloadTask) -> URL? {
        let dir = task.destinationURL
        let ext = task.isAudioOnly ? "mp3" : "mp4"
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) {
            // Ищем самый свежий файл с нужным расширением
            let matching = files
                .filter { $0.pathExtension == ext }
                .sorted { a, b in
                    let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    return da > db
                }
            return matching.first
        }
        return nil
    }
}
