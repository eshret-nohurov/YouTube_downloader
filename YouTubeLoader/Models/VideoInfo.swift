import Foundation

struct VideoInfo: Identifiable {
    let id = UUID()
    let title: String
    let duration: Int
    let thumbnailURL: URL?
    let url: String
    let availableFormats: [VideoFormat]
    let detailedFormats: [VideoFormat]
    let channel: String

    var durationString: String {
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
