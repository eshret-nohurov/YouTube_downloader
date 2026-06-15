import SwiftUI

struct InstallView: View {
    @ObservedObject var installer: InstallerService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            header
            Divider()

            // Контент
            if installer.step == .idle {
                preInstallView
            } else {
                installProgressView
            }

            Divider()

            // Кнопки
            footer
        }
        .frame(width: 520, height: 420)
    }

    // MARK: - Заголовок

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Установка зависимостей")
                    .font(.headline)
                Text("Необходимо для загрузки видео")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - До установки

    private var preInstallView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Что будет установлено
                VStack(alignment: .leading, spacing: 10) {
                    Text("Что будет установлено:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    componentRow(
                        icon: "arrow.down.app.fill",
                        color: .red,
                        name: "yt-dlp",
                        description: "Движок для скачивания видео с YouTube",
                        installed: YtDlpService.shared.isAvailable
                    )

                    componentRow(
                        icon: "film",
                        color: .green,
                        name: "ffmpeg",
                        description: "Объединение видео и аудио дорожек",
                        installed: YtDlpService.shared.isFfmpegAvailable
                    )
                }

                Divider()

                // Способ установки
                HStack(spacing: 8) {
                    Image(systemName: installer.hasHomebrew ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundStyle(installer.hasHomebrew ? .green : .blue)

                    if installer.hasHomebrew {
                        Text("Homebrew найден — установка через brew")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Homebrew не найден — скачаю напрямую с GitHub")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Примечание
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(.top, 2)
                    Text("Устанавливаются только официальные версии из проверенных источников. Пароль администратора не требуется.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(20)
        }
    }

    private func componentRow(icon: String, color: Color, name: String, description: String, installed: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if installed {
                        Text("уже установлен")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(.quaternary.opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Прогресс установки

    private var installProgressView: some View {
        VStack(spacing: 16) {
            // Статус
            HStack(spacing: 10) {
                if installer.step == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                } else if installer.step == .failed {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Text(installer.step.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if installer.step != .completed && installer.step != .failed {
                    Text("\(Int(installer.progress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Прогресс-бар
            if installer.step != .completed && installer.step != .failed {
                ProgressView(value: installer.progress)
                    .padding(.horizontal, 20)
            }

            // Вывод
            ScrollViewReader { proxy in
                ScrollView {
                    Text(installer.output)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .id("output")
                }
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .onChange(of: installer.output) { _ in
                    proxy.scrollTo("output", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Кнопки

    private var footer: some View {
        HStack {
            if installer.step == .failed {
                Button("Повторить") {
                    installer.install()
                }
            }

            Spacer()

            if installer.step == .idle {
                Button("Отмена") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])

                Button(action: { installer.install() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Установить")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            } else if installer.step == .completed {
                Button("Готово") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
            } else if installer.step == .failed {
                Button("Закрыть") { dismiss() }
            } else {
                // Installing — no close button
                Text("Подождите...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
    }
}
