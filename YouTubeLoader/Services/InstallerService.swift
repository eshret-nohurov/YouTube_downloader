import Foundation

enum InstallStep: String {
    case idle = ""
    case checking = "Проверка системы..."
    case installingBrew = "Установка Homebrew..."
    case installingYtDlp = "Установка yt-dlp..."
    case installingFfmpeg = "Установка ffmpeg..."
    case settingPermissions = "Настройка прав доступа..."
    case completed = "Установка завершена!"
    case failed = "Ошибка установки"
}

class InstallerService: ObservableObject {
    @Published var step: InstallStep = .idle
    @Published var output: String = ""
    @Published var isInstalling: Bool = false
    @Published var errorMessage: String?
    @Published var progress: Double = 0

    private var binDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("EshretYTDownloader/bin")
    }

    var brewPath: String? {
        let paths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }

    var hasHomebrew: Bool { brewPath != nil }

    // MARK: - Основная установка

    func install() {
        isInstalling = true
        output = ""
        errorMessage = nil
        progress = 0

        TelemetryService.shared.log(.info, category: "Установка", message: "Начало установки зависимостей")

        Task {
            await updateStep(.checking)
            await appendLine("Проверка системы...")

            if let brew = brewPath {
                await appendLine("Homebrew найден: \(brew)\n")
                await installViaBrew(brew)
            } else {
                await appendLine("Homebrew не найден — скачиваю напрямую\n")
                await installDirect()
            }

            await MainActor.run {
                self.isInstalling = false
                YtDlpService.shared.refreshPaths()
            }
        }
    }

    // MARK: - Установка через Homebrew

    private func installViaBrew(_ brew: String) async {
        // yt-dlp
        await updateStep(.installingYtDlp)
        await updateProgress(0.1)
        await appendLine("Устанавливаю yt-dlp...")

        let ytResult = await runProcess(path: brew, args: ["install", "yt-dlp"])
        if !ytResult.success {
            // Может быть уже установлен
            if ytResult.output.contains("already installed") {
                await appendLine("yt-dlp уже установлен\n")
            } else {
                await fail("Не удалось установить yt-dlp:\n\(ytResult.output)")
                return
            }
        } else {
            await appendLine("yt-dlp установлен успешно\n")
        }

        await updateProgress(0.5)

        // ffmpeg
        await updateStep(.installingFfmpeg)
        await appendLine("Устанавливаю ffmpeg...")

        let ffResult = await runProcess(path: brew, args: ["install", "ffmpeg"])
        if !ffResult.success {
            if ffResult.output.contains("already installed") {
                await appendLine("ffmpeg уже установлен\n")
            } else {
                await appendLine("Не удалось установить ffmpeg (не критично)\n")
                TelemetryService.shared.log(.warning, category: "Установка", message: "ffmpeg не установлен", details: ffResult.output)
            }
        } else {
            await appendLine("ffmpeg установлен успешно\n")
        }

        await updateProgress(1.0)
        await updateStep(.completed)
        await appendLine("\nВсе зависимости установлены! Можно начинать загрузку видео.")
        TelemetryService.shared.log(.info, category: "Установка", message: "Установка через Homebrew завершена")
    }

    // MARK: - Прямая установка (без Homebrew)

    private func installDirect() async {
        // Создаём директорию
        do {
            try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        } catch {
            await fail("Не удалось создать папку: \(error.localizedDescription)")
            return
        }

        // Скачиваем yt-dlp
        await updateStep(.installingYtDlp)
        await updateProgress(0.1)
        await appendLine("Скачиваю yt-dlp с GitHub...")

        let ytDlpURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
        let ytDlpDest = binDir.appendingPathComponent("yt-dlp")

        do {
            let (data, response) = try await URLSession.shared.data(from: ytDlpURL)

            guard let http = response as? HTTPURLResponse else {
                await fail("Неверный ответ сервера")
                return
            }

            guard http.statusCode == 200 else {
                await fail("Сервер вернул ошибку: \(http.statusCode)")
                return
            }

            guard data.count > 1000 else {
                await fail("Загруженный файл слишком мал — возможно ошибка сети")
                return
            }

            try data.write(to: ytDlpDest)
            await appendLine("Скачано: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            await updateProgress(0.6)

            TelemetryService.shared.log(.info, category: "Установка",
                message: "yt-dlp скачан",
                details: "\(data.count) байт → \(ytDlpDest.path)")

        } catch {
            await fail("Ошибка загрузки: \(error.localizedDescription)")
            return
        }

        // Делаем исполняемым
        await updateStep(.settingPermissions)
        await appendLine("Устанавливаю права доступа...")

        let chmodResult = await runProcess(path: "/bin/chmod", args: ["+x", ytDlpDest.path])
        if !chmodResult.success {
            await fail("Не удалось установить права: \(chmodResult.output)")
            return
        }

        await updateProgress(0.8)
        await appendLine("yt-dlp готов к работе: \(ytDlpDest.path)\n")

        // ffmpeg — пробуем скачать
        await updateStep(.installingFfmpeg)
        await appendLine("Скачиваю ffmpeg...")

        let ffmpegDest = binDir.appendingPathComponent("ffmpeg")
        let ffmpegURL = URL(string: "https://evermeet.cx/ffmpeg/getrelease/zip")!

        do {
            let (zipData, response) = try await URLSession.shared.data(from: ffmpegURL)

            if let http = response as? HTTPURLResponse, http.statusCode == 200, zipData.count > 10000 {
                // Сохраняем zip и распаковываем
                let zipPath = binDir.appendingPathComponent("ffmpeg.zip")
                try zipData.write(to: zipPath)

                let unzipResult = await runProcess(path: "/usr/bin/unzip", args: ["-o", zipPath.path, "-d", binDir.path])
                try? FileManager.default.removeItem(at: zipPath)

                if unzipResult.success && FileManager.default.fileExists(atPath: ffmpegDest.path) {
                    let _ = await runProcess(path: "/bin/chmod", args: ["+x", ffmpegDest.path])
                    await appendLine("ffmpeg установлен\n")
                    TelemetryService.shared.log(.info, category: "Установка", message: "ffmpeg установлен", details: ffmpegDest.path)
                } else {
                    await appendLine("ffmpeg: не удалось распаковать (не критично)\n")
                }
            } else {
                await appendLine("ffmpeg: не удалось скачать (не критично)\n")
                await appendLine("Без ffmpeg загрузка работает, но в некоторых\nформатах видео и аудио не будут объединены.\n")
            }
        } catch {
            await appendLine("ffmpeg: недоступен (\(error.localizedDescription))\n")
            await appendLine("Загрузка видео будет работать и без него.\n")
        }

        await updateProgress(1.0)
        await updateStep(.completed)
        await appendLine("\nУстановка завершена! Можно начинать загрузку видео.")
        TelemetryService.shared.log(.info, category: "Установка", message: "Прямая установка завершена")
    }

    // MARK: - Утилиты

    private func runProcess(path: String, args: [String]) async -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        var env = ProcessInfo.processInfo.environment
        let extra = "/opt/homebrew/bin:/usr/local/bin:/opt/local/bin"
        env["PATH"] = extra + ":" + (env["PATH"] ?? "/usr/bin:/bin")
        process.environment = env

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.output += text
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
            pipe.fileHandleForReading.readabilityHandler = nil

            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8) ?? ""
            let outData = pipe.fileHandleForReading.readDataToEndOfFile()
            let outText = String(data: outData, encoding: .utf8) ?? ""

            let combined = outText + errText
            return (process.terminationStatus == 0, combined)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    @MainActor
    private func updateStep(_ step: InstallStep) {
        self.step = step
    }

    @MainActor
    private func updateProgress(_ value: Double) {
        self.progress = value
    }

    @MainActor
    private func appendLine(_ text: String) {
        self.output += text + "\n"
    }

    @MainActor
    private func fail(_ message: String) {
        self.step = .failed
        self.errorMessage = message
        self.output += "\n\(message)\n"
        TelemetryService.shared.log(.error, category: "Установка", message: "Ошибка", details: message)
    }
}
