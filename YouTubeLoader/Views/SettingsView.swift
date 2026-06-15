import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("Основные", systemImage: "gear")
                }

            aboutView
                .tabItem {
                    Label("О программе", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 420)
    }

    // MARK: - Основные настройки

    private var generalSettings: some View {
        Form {
            Section {
                HStack {
                    Label("Папка загрузки", systemImage: "folder")
                    Spacer()
                    Text(viewModel.downloadFolder.lastPathComponent)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Button("Изменить") {
                        viewModel.selectFolder()
                    }
                    .controlSize(.small)
                }
            }

            Section {
                Picker(selection: $viewModel.defaultQuality) {
                    Text("Лучшее качество").tag("best")
                    Text("1080p (Full HD)").tag("1080p")
                    Text("720p (HD)").tag("720p")
                    Text("480p").tag("480p")
                } label: {
                    Label("Качество по умолчанию", systemImage: "sparkles")
                }
            }

            Section {
                Picker(selection: $viewModel.cookiesMode) {
                    Text("Из браузера").tag("browser")
                    Text("Из файла cookies.txt").tag("file")
                    Text("Без авторизации").tag("none")
                } label: {
                    Label("Способ авторизации", systemImage: "key")
                }

                if viewModel.cookiesMode == "browser" {
                    Picker(selection: $viewModel.cookiesBrowser) {
                        ForEach(YtDlpService.installedBrowsers(), id: \.id) { browser in
                            Text(browser.name).tag(browser.id)
                        }
                    } label: {
                        Label("Браузер", systemImage: "globe")
                    }
                }

                if viewModel.cookiesMode == "file" {
                    HStack {
                        Label("Файл cookies", systemImage: "doc")
                        Spacer()
                        Text(viewModel.cookiesFileDisplay)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Выбрать") {
                            viewModel.selectCookiesFile()
                        }
                        .controlSize(.small)
                    }
                }

                if viewModel.cookiesMode == "none" {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text("Используется обход через iOS-клиент YouTube. Работает не для всех видео.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Авторизация YouTube")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - О программе

    private var aboutView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("YouTube Загрузчик от Эшрета")
                .font(.title2)
                .fontWeight(.bold)

            Text("Версия 1.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 120)

            VStack(spacing: 6) {
                HStack {
                    Text("yt-dlp:")
                        .foregroundStyle(.secondary)
                    Text(viewModel.ytDlpVersion)
                        .font(.system(.body, design: .monospaced))
                }

                HStack {
                    Text("ffmpeg:")
                        .foregroundStyle(.secondary)
                    Text(YtDlpService.shared.isFfmpegAvailable ? "Установлен" : "Не найден")
                        .foregroundStyle(YtDlpService.shared.isFfmpegAvailable ? .green : .orange)
                }
            }
            .font(.subheadline)

            Spacer()
        }
        .padding()
    }
}
