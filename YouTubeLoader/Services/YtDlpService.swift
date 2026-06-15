import Foundation

enum YtDlpError: LocalizedError {
    case notInstalled
    case ffmpegNotInstalled
    case fetchFailed(String)
    case downloadFailed(String)
    case parseFailed(String)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "yt-dlp не найден. Установите через терминал: brew install yt-dlp"
        case .ffmpegNotInstalled:
            return "ffmpeg не найден. Установите через терминал: brew install ffmpeg"
        case .fetchFailed(let msg):
            return "Не удалось получить информацию о видео: \(msg)"
        case .downloadFailed(let msg):
            return "Ошибка загрузки: \(msg)"
        case .parseFailed(let msg):
            return "Ошибка разбора данных: \(msg)"
        case .invalidURL:
            return "Неверная ссылка. Поддерживаются ссылки YouTube"
        }
    }
}

class YtDlpService {
    static let shared = YtDlpService()

    private(set) var ytDlpPath: String?
    private(set) var ffmpegPath: String?
    private var currentInfoProcess: Process?

    var exportedCookiesPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("EshretYTDownloader/cookies.txt").path
    }

    var hasExportedCookies: Bool {
        FileManager.default.fileExists(atPath: exportedCookiesPath)
    }

    func exportCookiesViaTerminal(browser: String) {
        let cookiesDir = URL(fileURLWithPath: exportedCookiesPath).deletingLastPathComponent().path
        let ytdlp = ytDlpPath ?? "/opt/homebrew/bin/yt-dlp"
        let scriptPath = NSTemporaryDirectory() + "eshret_export_cookies.sh"

        // Определяем Python из шебанга yt-dlp
        var pythonPath = "/opt/homebrew/bin/python3"
        if let data = try? String(contentsOfFile: ytdlp, encoding: .utf8) {
            let firstLine = data.components(separatedBy: .newlines).first ?? ""
            if firstLine.hasPrefix("#!") {
                let p = firstLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
                if FileManager.default.fileExists(atPath: p) {
                    pythonPath = p
                }
            }
        }

        let script = """
        #!/bin/bash
        clear
        echo "================================================"
        echo "  Экспорт cookies из \(browser)"
        echo "================================================"
        echo ""
        echo "Если появится системный запрос пароля —"
        echo "введите пароль Mac и нажмите «Разрешить»."
        echo ""
        echo "Подождите..."
        echo ""

        mkdir -p "\(cookiesDir)"

        "\(pythonPath)" -c "
        from yt_dlp.cookies import extract_cookies_from_browser
        jar = extract_cookies_from_browser('\(browser)')
        jar.filename = '\(exportedCookiesPath)'
        jar.save(ignore_discard=True, ignore_expires=True)
        print('OK')
        " 2>&1

        if [ -f "\(exportedCookiesPath)" ] && [ -s "\(exportedCookiesPath)" ]; then
            echo ""
            echo "================================================"
            echo "  Cookies успешно сохранены!"
            echo "  Вернитесь в приложение."
            echo "================================================"
        else
            echo ""
            echo "Не удалось экспортировать cookies."
            echo "Убедитесь что вы авторизованы на YouTube в \(browser)."
        fi
        """

        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
        } catch {
            TelemetryService.shared.log(.error, category: "Cookies", message: "Не удалось создать скрипт", details: error.localizedDescription)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", scriptPath]
        do {
            try process.run()
            TelemetryService.shared.log(.info, category: "Cookies", message: "Экспорт cookies запущен в Terminal", details: browser)
        } catch {
            TelemetryService.shared.log(.error, category: "Cookies", message: "Ошибка запуска Terminal", details: error.localizedDescription)
        }
    }

    func cancelInfoFetch() {
        if let process = currentInfoProcess, process.isRunning {
            process.terminate()
            currentInfoProcess = nil
            TelemetryService.shared.log(.info, category: "YtDlp", message: "Запрос информации отменён пользователем")
        }
    }

    private init() {
        ytDlpPath = findBinary("yt-dlp")
        ffmpegPath = findBinary("ffmpeg")

        if let path = ytDlpPath {
            TelemetryService.shared.log(.info, category: "Система", message: "yt-dlp найден", details: path)
        } else {
            TelemetryService.shared.log(.error, category: "Система", message: "yt-dlp не найден")
        }

        if let path = ffmpegPath {
            TelemetryService.shared.log(.info, category: "Система", message: "ffmpeg найден", details: path)
        } else {
            TelemetryService.shared.log(.warning, category: "Система", message: "ffmpeg не найден — объединение форматов может не работать")
        }
    }

    func refreshPaths() {
        ytDlpPath = findBinary("yt-dlp")
        ffmpegPath = findBinary("ffmpeg")
        TelemetryService.shared.log(.info, category: "Система",
            message: "Пути обновлены",
            details: "yt-dlp: \(ytDlpPath ?? "нет") | ffmpeg: \(ffmpegPath ?? "нет")")
    }

    private var appBinDir: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("EshretYTDownloader/bin").path
    }

    private func findBinary(_ name: String) -> String? {
        let paths = [
            "\(appBinDir)/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/opt/local/bin/\(name)"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !result.isEmpty {
                return result
            }
        } catch {}

        return nil
    }

    var isAvailable: Bool { ytDlpPath != nil }
    var isFfmpegAvailable: Bool { ffmpegPath != nil }

    // MARK: - Cookies

    enum CookiesMode: String {
        case browser = "browser"
        case file = "file"
        case none = "none"
    }

    var cookiesMode: CookiesMode {
        CookiesMode(rawValue: UserDefaults.standard.string(forKey: "cookiesMode") ?? "browser") ?? .browser
    }

    var cookiesBrowser: String {
        UserDefaults.standard.string(forKey: "cookiesBrowser") ?? autoDetectBrowser()
    }

    var cookiesFilePath: String? {
        UserDefaults.standard.string(forKey: "cookiesFilePath")
    }

    func autoDetectBrowser() -> String {
        let browsers: [(String, String)] = [
            ("chrome", "/Applications/Google Chrome.app"),
            ("firefox", "/Applications/Firefox.app"),
            ("brave", "/Applications/Brave Browser.app"),
            ("edge", "/Applications/Microsoft Edge.app"),
        ]
        for (id, path) in browsers {
            if FileManager.default.fileExists(atPath: path) {
                return id
            }
        }
        return "safari"
    }

    static func installedBrowsers() -> [(id: String, name: String)] {
        var list: [(String, String)] = []
        let browsers: [(String, String, String)] = [
            ("chrome", "Google Chrome", "/Applications/Google Chrome.app"),
            ("firefox", "Firefox", "/Applications/Firefox.app"),
            ("brave", "Brave", "/Applications/Brave Browser.app"),
            ("edge", "Microsoft Edge", "/Applications/Microsoft Edge.app"),
        ]
        for (id, name, path) in browsers {
            if FileManager.default.fileExists(atPath: path) {
                list.append((id, name))
            }
        }
        list.append(("safari", "Safari"))
        return list
    }

    private func cookiesArgs() -> [String] {
        // Приоритет: экспортированный файл > ручной файл > браузер > без cookies
        if hasExportedCookies {
            TelemetryService.shared.log(.debug, category: "Cookies", message: "Используется экспортированный файл", details: exportedCookiesPath)
            return ["--cookies", exportedCookiesPath]
        }

        switch cookiesMode {
        case .browser:
            return ["--cookies-from-browser", cookiesBrowser]
        case .file:
            if let path = cookiesFilePath, FileManager.default.fileExists(atPath: path) {
                return ["--cookies", path]
            }
            return []
        case .none:
            return ["--extractor-args", "youtube:player_client=mweb"]
        }
    }

    private func makeProcess() -> Process {
        let process = Process()
        // Запускаем через /bin/zsh -c чтобы yt-dlp работал корректно
        // (прямой запуск Python через Process вызывает зависание при чтении cookies)
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/opt/local/bin"
        env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "/usr/bin:/bin")
        process.environment = env
        return process
    }

    private func shellCommand(_ args: [String]) -> [String] {
        let escaped = args.map { "'\($0.replacingOccurrences(of: "'", with: "'\\''"))'" }
        return ["-c", escaped.joined(separator: " ")]
    }

    // MARK: - Получение информации

    func getVideoInfo(url: String) async throws -> VideoInfo {
        guard let ytDlpPath = ytDlpPath else {
            throw YtDlpError.notInstalled
        }

        guard url.contains("youtube.com") || url.contains("youtu.be") || url.contains("youtube") else {
            throw YtDlpError.invalidURL
        }

        let ytArgs = [ytDlpPath, "--dump-json", "--no-playlist", "--socket-timeout", "15"] + cookiesArgs() + [url]

        TelemetryService.shared.log(.info, category: "YtDlp", message: "Запрос информации о видео",
            details: "\(url) | Аргументы: \(ytArgs.joined(separator: " "))")

        let process = makeProcess()
        process.arguments = shellCommand(ytArgs)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        currentInfoProcess = process

        // Читаем stdout/stderr асинхронно чтобы избежать deadlock при большом выводе
        var outData = Data()
        var errData = Data()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { outData.append(chunk) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { errData.append(chunk) }
        }

        try process.run()

        // Таймаут 60 секунд
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 60_000_000_000)
            if process.isRunning {
                TelemetryService.shared.log(.warning, category: "YtDlp", message: "Таймаут запроса — принудительное завершение")
                process.terminate()
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                timeoutTask.cancel()
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                self.currentInfoProcess = nil

                // Дочитываем остатки
                outData.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                errData.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

                guard process.terminationStatus == 0 else {
                    let errStr: String
                    if process.terminationStatus == 15 || process.terminationStatus == -1 {
                        errStr = "Превышено время ожидания (60 сек). Попробуйте другой способ авторизации."
                    } else {
                        errStr = String(data: errData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Неизвестная ошибка"
                    }
                    TelemetryService.shared.log(.error, category: "YtDlp", message: "Ошибка получения информации", details: errStr)
                    continuation.resume(throwing: YtDlpError.fetchFailed(errStr))
                    return
                }

                do {
                    guard let json = try JSONSerialization.jsonObject(with: outData) as? [String: Any] else {
                        throw YtDlpError.parseFailed("Неверный формат ответа")
                    }

                    let title = json["title"] as? String ?? "Без названия"
                    let duration = json["duration"] as? Int ?? (json["duration"] as? Double).map { Int($0) } ?? 0
                    let thumbnail = (json["thumbnail"] as? String).flatMap { URL(string: $0) }
                    let channel = json["channel"] as? String ?? json["uploader"] as? String ?? ""

                    // Парсим все форматы из JSON
                    var formats: [VideoFormat] = []
                    var detailedFormats: [VideoFormat] = []
                    var availableHeights = Set<Int>()

                    if let rawFormats = json["formats"] as? [[String: Any]] {
                        for fmt in rawFormats {
                            let vcodec = fmt["vcodec"] as? String ?? "none"
                            let acodec = fmt["acodec"] as? String ?? "none"
                            let height = fmt["height"] as? Int ?? 0
                            let fmtExt = fmt["ext"] as? String ?? ""
                            let fmtId = fmt["format_id"] as? String ?? ""
                            let fps = fmt["fps"] as? Int ?? (fmt["fps"] as? Double).map { Int($0) }
                            let filesize = fmt["filesize"] as? Int64 ?? fmt["filesize_approx"] as? Int64
                            let tbr = fmt["tbr"] as? Int ?? (fmt["tbr"] as? Double).map { Int($0) }

                            if height > 0 { availableHeights.insert(height) }

                            // Пропускаем storyboard и т.п.
                            guard vcodec != "none" || acodec != "none" else { continue }
                            guard fmtExt != "mhtml" else { continue }

                            let hasVideo = vcodec != "none"
                            let hasAudio = acodec != "none"

                            // Подробный формат
                            let codecStr: String
                            if hasVideo && hasAudio {
                                codecStr = "\(Self.shortCodec(vcodec))+\(Self.shortCodec(acodec))"
                            } else if hasVideo {
                                codecStr = Self.shortCodec(vcodec)
                            } else {
                                codecStr = Self.shortCodec(acodec)
                            }

                            let qualityStr: String
                            if hasVideo {
                                let label = height > 0 ? "\(height)p" : ""
                                let fpsStr = (fps ?? 0) > 30 ? " \(fps!)fps" : ""
                                let typeStr = hasAudio ? "" : " (видео)"
                                qualityStr = "\(label)\(fpsStr)\(typeStr)"
                            } else {
                                let abr = fmt["abr"] as? Int ?? (fmt["abr"] as? Double).map { Int($0) } ?? 0
                                qualityStr = "Аудио \(abr)kbps"
                            }

                            detailedFormats.append(VideoFormat(
                                id: "detail_\(fmtId)",
                                quality: qualityStr,
                                resolution: height > 0 ? "\(height)p" : "",
                                ext: fmtExt,
                                fileSize: filesize,
                                fps: fps,
                                formatString: fmtId,
                                isAudioOnly: !hasVideo,
                                codec: codecStr,
                                bitrate: tbr
                            ))
                        }
                    }

                    // Пресеты для быстрого выбора
                    // H.264 предпочтительнее AV1/VP9 — совместимость с QuickTime
                    formats.append(VideoFormat(
                        id: "best", quality: "Лучшее качество", resolution: "max",
                        ext: "mp4", fileSize: nil, fps: nil,
                        formatString: "bestvideo[vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[vcodec^=avc1]+bestaudio/bestvideo+bestaudio/best",
                        isAudioOnly: false
                    ))

                    let presets: [(String, String, Int)] = [
                        ("2160p", "2160p (4K)", 2160),
                        ("1440p", "1440p (2K)", 1440),
                        ("1080p", "1080p (Full HD)", 1080),
                        ("720p", "720p (HD)", 720),
                        ("480p", "480p", 480),
                        ("360p", "360p", 360),
                    ]

                    for (id, quality, height) in presets {
                        if availableHeights.contains(where: { $0 >= height }) {
                            formats.append(VideoFormat(
                                id: id, quality: quality, resolution: "\(height)p",
                                ext: "mp4", fileSize: nil, fps: nil,
                                formatString: "bestvideo[vcodec^=avc1][height<=\(height)]+bestaudio[acodec^=mp4a]/bestvideo[vcodec^=avc1][height<=\(height)]+bestaudio/bestvideo[height<=\(height)]+bestaudio/best[height<=\(height)]",
                                isAudioOnly: false
                            ))
                        }
                    }

                    formats.append(VideoFormat(
                        id: "audio", quality: "Только аудио (MP3)", resolution: "",
                        ext: "mp3", fileSize: nil, fps: nil,
                        formatString: "bestaudio", isAudioOnly: true
                    ))

                    // Сортируем подробные форматы: видео по высоте (убыв), потом аудио
                    let sortedDetailed = detailedFormats.sorted { a, b in
                        if a.isAudioOnly != b.isAudioOnly { return !a.isAudioOnly }
                        let ha = Int(a.resolution.replacingOccurrences(of: "p", with: "")) ?? 0
                        let hb = Int(b.resolution.replacingOccurrences(of: "p", with: "")) ?? 0
                        if ha != hb { return ha > hb }
                        return (a.bitrate ?? 0) > (b.bitrate ?? 0)
                    }

                    let videoInfo = VideoInfo(
                        title: title, duration: duration, thumbnailURL: thumbnail,
                        url: url, availableFormats: formats, detailedFormats: sortedDetailed, channel: channel
                    )

                    TelemetryService.shared.log(.info, category: "YtDlp",
                        message: "Информация получена",
                        details: "\(title) | \(formats.count) форматов | Качества: \(availableHeights.sorted().map { "\($0)p" }.joined(separator: ", "))")
                    continuation.resume(returning: videoInfo)
                } catch let error as YtDlpError {
                    continuation.resume(throwing: error)
                } catch {
                    TelemetryService.shared.log(.error, category: "YtDlp", message: "Ошибка парсинга", details: error.localizedDescription)
                    continuation.resume(throwing: YtDlpError.parseFailed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Загрузка

    func download(task: DownloadTask) async throws {
        guard let ytDlpPath = ytDlpPath else {
            throw YtDlpError.notInstalled
        }

        TelemetryService.shared.log(.info, category: "Загрузка",
            message: "Начало: \(task.videoTitle)",
            details: "Качество: \(task.quality) | Папка: \(task.destinationURL.path)")

        let process = makeProcess()

        let outputTemplate = task.destinationURL.appendingPathComponent("%(title)s.%(ext)s").path

        let ytArgs: [String]
        if task.isAudioOnly {
            ytArgs = [ytDlpPath,
                "-x", "--audio-format", "mp3",
                "--newline", "--no-playlist"
            ] + cookiesArgs() + [
                "-o", outputTemplate,
                task.url
            ]
        } else {
            // -S vcodec:h264 — предпочитает H.264 (совместим с QuickTime)
            // --recode-video mp4 — если попался AV1/VP9, перекодирует в H.264
            ytArgs = [ytDlpPath,
                "-f", task.formatString,
                "-S", "+vcodec:h264,+acodec:m4a",
                "--merge-output-format", "mp4",
                "--recode-video", "mp4",
                "--newline", "--no-playlist"
            ] + cookiesArgs() + [
                "-o", outputTemplate,
                task.url
            ]
        }
        process.arguments = shellCommand(ytArgs)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        task.process = process

        await MainActor.run {
            task.status = .downloading
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.parseProgress(output: output, task: task)
            }
        }

        try process.run()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil

                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                DispatchQueue.main.async {
                    if proc.terminationStatus == 0 {
                        task.status = .completed
                        task.progress = 1.0
                        task.speed = ""
                        task.eta = ""
                        TelemetryService.shared.log(.info, category: "Загрузка", message: "Завершена: \(task.videoTitle)")
                        continuation.resume()
                    } else if task.status == .cancelled {
                        TelemetryService.shared.log(.info, category: "Загрузка", message: "Отменена: \(task.videoTitle)")
                        continuation.resume()
                    } else {
                        let msg = errStr.isEmpty ? "Код ошибки: \(proc.terminationStatus)" : errStr
                        task.status = .failed
                        task.errorMessage = msg
                        TelemetryService.shared.log(.error, category: "Загрузка", message: "Ошибка: \(task.videoTitle)", details: msg)
                        continuation.resume(throwing: YtDlpError.downloadFailed(msg))
                    }
                }
            }
        }
    }

    // MARK: - Парсинг прогресса

    private func parseProgress(output: String, task: DownloadTask) {
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.contains("[download]") {
                if trimmed.contains("%") && !trimmed.contains("100%") {
                    // Процент: [download]  45.2% of 150.00MiB at 2.50MiB/s ETA 00:35
                    if let range = trimmed.range(of: #"\d+\.?\d*(?=%)"#, options: .regularExpression) {
                        if let percent = Double(trimmed[range]) {
                            task.progress = min(percent / 100.0, 0.99)
                        }
                    }

                    if let range = trimmed.range(of: #"[\d.]+\s*\w+/s"#, options: .regularExpression) {
                        task.speed = String(trimmed[range])
                    }

                    if let range = trimmed.range(of: #"ETA\s+[\d:]+"#, options: .regularExpression) {
                        task.eta = String(trimmed[range]).replacingOccurrences(of: "ETA ", with: "")
                    }
                } else if trimmed.contains("100%") {
                    task.progress = 1.0
                    task.speed = ""
                    task.eta = ""
                } else if trimmed.contains("Destination:") {
                    if let dest = trimmed.components(separatedBy: "Destination: ").last {
                        task.filePath = dest
                        TelemetryService.shared.log(.debug, category: "Загрузка", message: "Файл", details: dest)
                    }
                }
            } else if trimmed.contains("[Merger]") || trimmed.contains("[ffmpeg]") {
                task.status = .merging
                task.speed = ""
                task.eta = ""
                TelemetryService.shared.log(.info, category: "Загрузка", message: "Объединение аудио и видео: \(task.videoTitle)")
            }
        }
    }

    static func shortCodec(_ codec: String) -> String {
        if codec.hasPrefix("avc1") { return "H.264" }
        if codec.hasPrefix("av01") { return "AV1" }
        if codec == "vp9" || codec.hasPrefix("vp09") { return "VP9" }
        if codec.hasPrefix("mp4a") { return "AAC" }
        if codec == "opus" { return "Opus" }
        if codec == "vorbis" { return "Vorbis" }
        if codec.hasPrefix("hev1") || codec.hasPrefix("hvc1") { return "H.265" }
        return codec
    }
}
