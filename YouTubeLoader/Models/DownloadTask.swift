import Foundation

enum DownloadStatus: String {
    case waiting = "Ожидание"
    case downloading = "Загрузка"
    case merging = "Объединение"
    case completed = "Завершено"
    case failed = "Ошибка"
    case cancelled = "Отменено"

    var icon: String {
        switch self {
        case .waiting: return "clock"
        case .downloading: return "arrow.down.circle.fill"
        case .merging: return "gearshape.2.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .waiting: return "secondary"
        case .downloading: return "blue"
        case .merging: return "orange"
        case .completed: return "green"
        case .failed: return "red"
        case .cancelled: return "gray"
        }
    }
}

class DownloadTask: ObservableObject, Identifiable {
    let id = UUID()
    let videoTitle: String
    let quality: String
    let destinationURL: URL
    let url: String
    let formatString: String
    let isAudioOnly: Bool
    let createdAt: Date

    @Published var status: DownloadStatus = .waiting
    @Published var progress: Double = 0
    @Published var speed: String = ""
    @Published var eta: String = ""
    @Published var errorMessage: String?
    @Published var filePath: String?

    var process: Process?

    init(videoTitle: String, quality: String, destinationURL: URL, url: String, formatString: String, isAudioOnly: Bool) {
        self.videoTitle = videoTitle
        self.quality = quality
        self.destinationURL = destinationURL
        self.url = url
        self.formatString = formatString
        self.isAudioOnly = isAudioOnly
        self.createdAt = Date()
    }
}
