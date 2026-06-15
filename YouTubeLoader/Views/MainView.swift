import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var installer = InstallerService()
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var telemetry: TelemetryService

    @State private var showInstaller = false
    @State private var showCookieSetup = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 420)
        } detail: {
            detailView
        }
        .navigationTitle("YouTube Загрузчик от Эшрета")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showCookieSetup = true }) {
                    Label("Настройка cookies", systemImage: "key")
                }
                .help("Настройка cookies для YouTube")

                Button(action: { viewModel.showLogs.toggle() }) {
                    Label("Журнал", systemImage: "doc.text.magnifyingglass")
                }
                .help("Журнал событий")
            }
        }
        .sheet(isPresented: $viewModel.showLogs) {
            LogView()
                .environmentObject(telemetry)
        }
        .sheet(isPresented: $showInstaller, onDismiss: {
            viewModel.refreshDependencies()
        }) {
            InstallView(installer: installer)
        }
        .sheet(isPresented: $showCookieSetup) {
            SetupView(
                onComplete: { showCookieSetup = false },
                onSkip: { showCookieSetup = false }
            )
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Заголовок
            HStack {
                Label("Загрузки", systemImage: "arrow.down.circle")
                    .font(.headline)
                Spacer()
                if !downloadManager.tasks.isEmpty {
                    Button(action: { downloadManager.clearCompleted() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Очистить завершённые")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if downloadManager.tasks.isEmpty {
                emptyDownloadsView
            } else {
                downloadsList
            }
        }
        .background(.ultraThinMaterial)
    }

    private var emptyDownloadsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "arrow.down.circle.dotted")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.tertiary)
            Text("Нет загрузок")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Вставьте ссылку YouTube\nи нажмите «Найти»")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var downloadsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // Активные
                if !downloadManager.activeTasks.isEmpty {
                    Section {
                        ForEach(downloadManager.activeTasks) { task in
                            DownloadRowView(task: task)
                                .environmentObject(downloadManager)
                        }
                    } header: {
                        sectionHeader("Активные", count: downloadManager.activeTasks.count)
                    }
                }

                // Завершённые
                if !downloadManager.completedTasks.isEmpty {
                    Section {
                        ForEach(downloadManager.completedTasks) { task in
                            DownloadRowView(task: task)
                                .environmentObject(downloadManager)
                        }
                    } header: {
                        sectionHeader("Завершённые", count: downloadManager.completedTasks.count)
                    }
                }

                // С ошибками
                if !downloadManager.failedTasks.isEmpty {
                    Section {
                        ForEach(downloadManager.failedTasks) { task in
                            DownloadRowView(task: task)
                                .environmentObject(downloadManager)
                        }
                    } header: {
                        sectionHeader("Ошибки", count: downloadManager.failedTasks.count)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text("(\(count))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    // MARK: - Detail

    private var detailView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Предупреждение yt-dlp
                if !viewModel.isYtDlpAvailable {
                    dependencyWarning
                }

                // Поле ввода URL
                urlInputCard

                // Ошибка
                if let error = viewModel.errorMessage {
                    if error.contains("Operation not permitted") || error.contains("Errno 1") {
                        cookiesPermissionBanner
                    } else if error.contains("Превышено время") {
                        timeoutBanner
                    } else if error.contains("bot") || error.contains("Sign in") || error.contains("cookies") {
                        botErrorBanner
                    } else {
                        errorBanner(error)
                    }
                }

                // Загрузка
                if viewModel.isLoading {
                    loadingView
                }

                // Превью видео
                if let info = viewModel.videoInfo {
                    VideoPreviewView(
                        videoInfo: info,
                        selectedFormat: $viewModel.selectedFormat,
                        downloadFolder: viewModel.downloadFolder,
                        onSelectFolder: { viewModel.selectDownloadFolder() },
                        onDownload: { viewModel.startDownload(manager: downloadManager) }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Пустое состояние
                if !viewModel.isLoading && viewModel.videoInfo == nil && viewModel.errorMessage == nil {
                    welcomeView
                }

                Spacer(minLength: 40)
            }
            .padding(28)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.videoInfo != nil)
            .animation(.easeInOut(duration: 0.25), value: viewModel.errorMessage)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Компоненты

    private var urlInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ссылка на видео", systemImage: "link")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("https://youtube.com/watch?v=...", text: $viewModel.urlText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { viewModel.fetchVideoInfo() }

                Button(action: { viewModel.pasteFromClipboard() }) {
                    Image(systemName: "doc.on.clipboard")
                        .frame(width: 20)
                }
                .help("Вставить из буфера обмена")

                if !viewModel.urlText.isEmpty {
                    Button(action: { viewModel.clearForm() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)
                    .help("Очистить")
                }

                Button(action: { viewModel.fetchVideoInfo() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                        Text("Найти")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.urlText.isEmpty || viewModel.isLoading)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    private var dependencyWarning: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Нужны дополнительные компоненты")
                        .font(.headline)
                    Text("Для загрузки видео необходимо установить yt-dlp и ffmpeg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                // Статус yt-dlp
                HStack(spacing: 5) {
                    Image(systemName: viewModel.isYtDlpAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(viewModel.isYtDlpAvailable ? .green : .red)
                        .font(.caption)
                    Text("yt-dlp")
                        .font(.subheadline)
                }

                // Статус ffmpeg
                HStack(spacing: 5) {
                    Image(systemName: viewModel.isFfmpegAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(viewModel.isFfmpegAvailable ? .green : .orange)
                        .font(.caption)
                    Text("ffmpeg")
                        .font(.subheadline)
                }

                Spacer()

                // Кнопка установки
                Button(action: { showInstaller = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Установить")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .font(.title3)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Button(action: { viewModel.errorMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.red.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private var timeoutBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text("Не удалось получить cookies из браузера")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.errorMessage = nil }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("macOS блокирует доступ к cookies Chrome из приложения. Нужно один раз экспортировать cookies через Терминал — это займёт 10 секунд.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(action: {
                    YtDlpService.shared.exportCookiesViaTerminal(browser: YtDlpService.shared.cookiesBrowser)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal.fill")
                        Text("Экспортировать cookies")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)

                Text("Откроется Терминал. После завершения вернитесь сюда.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if YtDlpService.shared.hasExportedCookies {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Cookies экспортированы!")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    Button("Повторить поиск") {
                        viewModel.errorMessage = nil
                        viewModel.fetchVideoInfo()
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var cookiesPermissionBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text("Нет доступа к cookies Safari")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.errorMessage = nil }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("macOS блокирует доступ к cookies Safari.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                // Вариант 1: без авторизации
                Button(action: {
                    UserDefaults.standard.set("none", forKey: "cookiesMode")
                    viewModel.errorMessage = nil
                    viewModel.fetchVideoInfo()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Попробовать без авторизации")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                // Вариант 2: другой браузер
                let browsers = YtDlpService.installedBrowsers()
                if !browsers.isEmpty {
                    HStack(spacing: 8) {
                        Text("Или cookies из:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(browsers.prefix(3), id: \.id) { browser in
                            Button(browser.name) {
                                UserDefaults.standard.set("browser", forKey: "cookiesMode")
                                UserDefaults.standard.set(browser.id, forKey: "cookiesBrowser")
                                viewModel.errorMessage = nil
                                viewModel.fetchVideoInfo()
                            }
                            .controlSize(.small)
                            .font(.caption)
                        }
                    }
                }

                // Вариант 3: Full Disk Access
                HStack(spacing: 6) {
                    Text("Для Safari:")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Button("Дать полный доступ к диску") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                    }
                    .controlSize(.small)
                    .font(.caption)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var botErrorBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.key.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text("YouTube требует авторизацию")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.errorMessage = nil }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("YouTube заблокировал запрос. Выберите способ решения:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                // Вариант 1: без авторизации
                HStack(spacing: 8) {
                    Button(action: {
                        UserDefaults.standard.set("none", forKey: "cookiesMode")
                        viewModel.errorMessage = nil
                        viewModel.fetchVideoInfo()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Попробовать без авторизации")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Text("— работает для большинства видео")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Вариант 2: cookies из браузера
                let browsers = YtDlpService.installedBrowsers()
                if !browsers.isEmpty {
                    HStack(spacing: 8) {
                        Text("Или cookies из:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(browsers.prefix(3), id: \.id) { browser in
                            Button(browser.name) {
                                UserDefaults.standard.set("browser", forKey: "cookiesMode")
                                UserDefaults.standard.set(browser.id, forKey: "cookiesBrowser")
                                viewModel.errorMessage = nil
                                viewModel.fetchVideoInfo()
                            }
                            .controlSize(.small)
                            .font(.caption)
                        }
                    }
                }

                // Настройки
                Button("Другие варианты в Настройках") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Получение информации о видео...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: { viewModel.cancelFetch() }) {
                Text("Отмена")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("YouTube Загрузчик от Эшрета")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Вставьте ссылку на видео YouTube\nи выберите качество для скачивания")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 100)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                instructionRow("1", "Скопируйте ссылку на YouTube видео")
                instructionRow("2", "Нажмите «Вставить» или введите вручную")
                instructionRow("3", "Нажмите «Найти» для получения информации")
                instructionRow("4", "Выберите качество и нажмите «Скачать»")
            }
        }
        .padding(40)
        .frame(maxWidth: 500)
        .background(.regularMaterial)
        .cornerRadius(16)
    }

    private func instructionRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
