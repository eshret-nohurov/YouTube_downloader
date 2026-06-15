import SwiftUI

struct SetupView: View {
    @Environment(\.dismiss) private var dismiss
    var onComplete: () -> Void
    var onSkip: () -> Void

    @State private var step: SetupStep = .welcome
    @State private var selectedBrowser: String = ""
    @State private var detectedBrowsers: [(id: String, name: String)] = []
    @State private var isExporting = false
    @State private var isTesting = false
    @State private var checkTimer: Timer?

    // Настройки
    @State private var selectedQuality: String = "best"
    @State private var downloadFolder: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!

    enum SetupStep {
        case welcome
        case preferences
        case exporting
        case testing
        case success
        case needAuth
    }

    var body: some View {
        VStack(spacing: 0) {
            progressBar

            Group {
                switch step {
                case .welcome: welcomeStep
                case .preferences: preferencesStep
                case .exporting: exportingStep
                case .testing: testingStep
                case .success: successStep
                case .needAuth: needAuthStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 540, height: 520)
        .onAppear {
            detectedBrowsers = YtDlpService.installedBrowsers()
            if let first = detectedBrowsers.first {
                selectedBrowser = first.id
            }
            if let saved = UserDefaults.standard.string(forKey: "downloadFolder"),
               FileManager.default.fileExists(atPath: saved) {
                downloadFolder = URL(fileURLWithPath: saved)
            }
            if let q = UserDefaults.standard.string(forKey: "defaultQuality"), !q.isEmpty {
                selectedQuality = q
            }
        }
        .onDisappear {
            checkTimer?.invalidate()
        }
    }

    // MARK: - Прогресс

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= stepIndex ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var stepIndex: Int {
        switch step {
        case .welcome: return 0
        case .preferences: return 1
        case .exporting, .testing: return 2
        case .success, .needAuth: return 3
        }
    }

    // MARK: - Шаг 1: Приветствие и выбор браузера

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(spacing: 6) {
                Text("YouTube Загрузчик от Эшрета")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Выберите браузер, в котором вы\nавторизованы на YouTube")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if detectedBrowsers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Не найден Chrome, Firefox или Brave.\nУстановите один из них и авторизуйтесь на YouTube.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(detectedBrowsers, id: \.id) { browser in
                        browserRow(browser)
                    }
                }
                .padding(.horizontal, 60)
            }

            Spacer()

            navigationButtons(
                back: nil,
                next: ("Далее", { step = .preferences }),
                nextDisabled: selectedBrowser.isEmpty,
                showSkip: true
            )
        }
    }

    private func browserRow(_ browser: (id: String, name: String)) -> some View {
        Button(action: { selectedBrowser = browser.id }) {
            HStack(spacing: 12) {
                Image(systemName: selectedBrowser == browser.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedBrowser == browser.id ? .blue : .secondary)
                    .font(.title3)
                Text(browser.name)
                    .font(.body)
                Spacer()
            }
            .padding(12)
            .background(selectedBrowser == browser.id ? Color.blue.opacity(0.08) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selectedBrowser == browser.id ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Шаг 2: Качество и папка

    private var preferencesStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "gearshape.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text("Настройки загрузки")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                // Качество
                VStack(alignment: .leading, spacing: 8) {
                    Label("Качество по умолчанию", systemImage: "sparkles")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(spacing: 6) {
                        qualityOption("best", "Лучшее качество", "Максимальное доступное разрешение")
                        qualityOption("1080p", "1080p (Full HD)", "Оптимальный баланс качества и размера")
                        qualityOption("720p", "720p (HD)", "Хорошее качество, небольшой размер")
                        qualityOption("480p", "480p", "Экономия места на диске")
                    }
                }

                Divider()

                // Папка загрузки
                VStack(alignment: .leading, spacing: 8) {
                    Label("Папка загрузки", systemImage: "folder.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.blue)
                        Text(downloadFolder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button("Изменить") {
                            selectFolder()
                        }
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.secondary.opacity(0.15), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            navigationButtons(
                back: ("Назад", { step = .welcome }),
                next: ("Далее", {
                    savePreferences()
                    startExport()
                }),
                nextDisabled: false,
                showSkip: false
            )
        }
    }

    private func qualityOption(_ id: String, _ title: String, _ subtitle: String) -> some View {
        Button(action: { selectedQuality = id }) {
            HStack(spacing: 10) {
                Image(systemName: selectedQuality == id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedQuality == id ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(selectedQuality == id ? Color.blue.opacity(0.06) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Выберите папку для загрузки"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            downloadFolder = url
        }
    }

    private func savePreferences() {
        UserDefaults.standard.set(selectedQuality, forKey: "defaultQuality")
        UserDefaults.standard.set(downloadFolder.path, forKey: "downloadFolder")
        UserDefaults.standard.set(selectedBrowser, forKey: "cookiesBrowser")
    }

    // MARK: - Шаг 3: Экспорт

    private var exportingStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "terminal.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Настройка доступа к YouTube")
                    .font(.title3)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 10) {
                    instructionItem("1", "Откроется окно Терминала")
                    instructionItem("2", "Если система попросит пароль — введите пароль Mac и нажмите «Разрешить»")
                    instructionItem("3", "Дождитесь сообщения «Cookies сохранены»")
                    instructionItem("4", "Вернитесь сюда и нажмите «Проверить»")
                }
                .frame(maxWidth: 380)
            }

            if isExporting {
                ProgressView("Ожидание...")
                    .padding(.top, 8)
            }

            Spacer()

            navigationButtons(
                back: ("Назад", { checkTimer?.invalidate(); step = .preferences }),
                next: ("Я завершил, проверить", { runTest() }),
                nextDisabled: false,
                showSkip: false
            )
        }
    }

    private func instructionItem(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.blue))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Шаг 4: Тестирование

    private var testingStep: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Проверяю подключение к YouTube...")
                .font(.headline)
            Text("Это может занять несколько секунд")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Шаг 5a: Успех

    private var successStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Всё готово!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Cookies получены. Можно загружать видео!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Итог настроек
            VStack(spacing: 6) {
                HStack {
                    Text("Качество:")
                        .foregroundStyle(.secondary)
                    Text(qualityName(selectedQuality))
                }
                HStack {
                    Text("Папка:")
                        .foregroundStyle(.secondary)
                    Text(downloadFolder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                }
                HStack {
                    Text("Браузер:")
                        .foregroundStyle(.secondary)
                    Text(browserName(selectedBrowser))
                }
            }
            .font(.subheadline)
            .padding(16)
            .background(.regularMaterial)
            .cornerRadius(10)

            Spacer()

            Button(action: {
                UserDefaults.standard.set("file", forKey: "cookiesMode")
                savePreferences()
                onComplete()
            }) {
                Text("Начать работу")
                    .fontWeight(.semibold)
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Шаг 5b: Нужна авторизация

    private var needAuthStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Нужна авторизация на YouTube")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Откройте \(browserName(selectedBrowser)), зайдите на youtube.com\nи войдите в аккаунт Google.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Открыть YouTube в \(browserName(selectedBrowser))") {
                openYouTubeInBrowser()
            }

            Spacer()

            HStack {
                Button("Выбрать другой браузер") {
                    step = .welcome
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: { startExport() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Повторить")
                    }
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
    }

    // MARK: - Общие кнопки навигации

    private func navigationButtons(
        back: (String, () -> Void)?,
        next: (String, () -> Void),
        nextDisabled: Bool,
        showSkip: Bool
    ) -> some View {
        HStack {
            if showSkip {
                Button("Пропустить") { onSkip() }
                    .foregroundStyle(.secondary)
            } else if let back = back {
                Button(back.0) { back.1() }
            }

            Spacer()

            Button(action: next.1) {
                HStack(spacing: 6) {
                    Text(next.0)
                    Image(systemName: "arrow.right")
                }
                .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .disabled(nextDisabled)
        }
        .padding(24)
    }

    // MARK: - Действия

    private func startExport() {
        step = .exporting
        isExporting = true
        UserDefaults.standard.set(selectedBrowser, forKey: "cookiesBrowser")
        YtDlpService.shared.exportCookiesViaTerminal(browser: selectedBrowser)

        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if YtDlpService.shared.hasExportedCookies {
                checkTimer?.invalidate()
                isExporting = false
            }
        }
    }

    private func runTest() {
        checkTimer?.invalidate()
        step = .testing
        isTesting = true

        Task {
            do {
                YtDlpService.shared.refreshPaths()
                let _ = try await YtDlpService.shared.getVideoInfo(url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
                await MainActor.run {
                    step = .success
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    step = .needAuth
                    isTesting = false
                }
            }
        }
    }

    private func qualityName(_ id: String) -> String {
        switch id {
        case "best": return "Лучшее качество"
        case "1080p": return "1080p (Full HD)"
        case "720p": return "720p (HD)"
        case "480p": return "480p"
        default: return id
        }
    }

    private func browserName(_ id: String) -> String {
        switch id {
        case "chrome": return "Chrome"
        case "firefox": return "Firefox"
        case "brave": return "Brave"
        case "edge": return "Edge"
        default: return id
        }
    }

    private func openYouTubeInBrowser() {
        let bundleId: String
        switch selectedBrowser {
        case "chrome": bundleId = "com.google.Chrome"
        case "firefox": bundleId = "org.mozilla.firefox"
        case "brave": bundleId = "com.brave.Browser"
        case "edge": bundleId = "com.microsoft.edgemac"
        default: bundleId = "com.google.Chrome"
        }
        NSWorkspace.shared.open(
            [URL(string: "https://youtube.com")!],
            withAppBundleIdentifier: bundleId,
            options: [],
            additionalEventParamDescriptor: nil,
            launchIdentifiers: nil
        )
    }
}
