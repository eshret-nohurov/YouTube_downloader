import Foundation

struct VideoFormat: Identifiable, Hashable {
    let id: String
    let quality: String
    let resolution: String
    let ext: String
    let fileSize: Int64?
    let fps: Int?
    let formatString: String
    let isAudioOnly: Bool
    let codec: String
    let bitrate: Int?

    init(id: String, quality: String, resolution: String, ext: String,
         fileSize: Int64?, fps: Int?, formatString: String, isAudioOnly: Bool,
         codec: String = "", bitrate: Int? = nil) {
        self.id = id
        self.quality = quality
        self.resolution = resolution
        self.ext = ext
        self.fileSize = fileSize
        self.fps = fps
        self.formatString = formatString
        self.isAudioOnly = isAudioOnly
        self.codec = codec
        self.bitrate = bitrate
    }

    var displayName: String {
        if isAudioOnly {
            return "Только аудио (MP3)"
        }
        var name = quality
        if let fps = fps, fps > 30 {
            name += " \(fps)fps"
        }
        if let size = fileSize {
            name += " (~\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))"
        }
        return name
    }

    var detailLine: String {
        var parts: [String] = []
        if !resolution.isEmpty { parts.append(resolution) }
        if !ext.isEmpty { parts.append(ext.uppercased()) }
        if !codec.isEmpty { parts.append(codec) }
        if let fps = fps { parts.append("\(fps)fps") }
        if let br = bitrate { parts.append("\(br)k") }
        if let size = fileSize {
            parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
        }
        return parts.joined(separator: " · ")
    }
}
