import SwiftUI

struct DownloadRowView: View {
    @ObservedObject var task: DownloadTask
    @EnvironmentObject var downloadManager: DownloadManager

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Заголовок
            HStack(spacing: 6) {
                statusIcon
                Text(task.videoTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }

            // Качество
            Text(task.quality)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Прогресс-бар
            if task.status == .downloading || task.status == .merging {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: task.status == .merging
                                            ? [.orange, .yellow]
                                            : [.blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * task.progress)
                                .animation(.easeInOut(duration: 0.3), value: task.progress)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        if task.status == .merging {
                            Text("Объединение...")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        } else {
                            Text("\(Int(task.progress * 100))%")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .monospacedDigit()
                        }

                        Spacer()

                        if !task.speed.isEmpty {
                            Text(task.speed)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        if !task.eta.isEmpty {
                            Text("~ \(task.eta)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                    }
                }
            }

            // Статус завершения
            if task.status == .completed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Загружено")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            // Ошибка
            if task.status == .failed, let error = task.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            // Кнопки управления
            if isHovered {
                actionButtons
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.05) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary, lineWidth: isHovered ? 1 : 0)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            contextMenuItems
        }
    }

    // MARK: - Иконка статуса

    private var statusIcon: some View {
        Group {
            switch task.status {
            case .waiting:
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
            case .downloading:
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
            case .merging:
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(.orange)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .cancelled:
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.gray)
            }
        }
        .font(.caption)
    }

    // MARK: - Кнопки действий

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if task.status == .downloading || task.status == .waiting || task.status == .merging {
                Button(action: { downloadManager.cancelDownload(task) }) {
                    Label("Отмена", systemImage: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            if task.status == .completed {
                Button(action: { downloadManager.playFile(task) }) {
                    Label("Воспроизвести", systemImage: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)

                Button(action: { downloadManager.openInFinder(task) }) {
                    Label("В Finder", systemImage: "folder")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            if task.status == .failed || task.status == .cancelled {
                Button(action: { downloadManager.retryDownload(task) }) {
                    Label("Повтор", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            Spacer()

            Button(action: { downloadManager.removeDownload(task) }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Контекстное меню

    @ViewBuilder
    private var contextMenuItems: some View {
        if task.status == .completed {
            Button("Воспроизвести") {
                downloadManager.playFile(task)
            }
            Button("Показать в Finder") {
                downloadManager.openInFinder(task)
            }
        }

        if task.status == .failed || task.status == .cancelled {
            Button("Повторить загрузку") {
                downloadManager.retryDownload(task)
            }
        }

        if task.status == .downloading || task.status == .waiting {
            Button("Отменить") {
                downloadManager.cancelDownload(task)
            }
        }

        Divider()

        Button("Скопировать ссылку") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(task.url, forType: .string)
        }

        Button("Удалить из списка") {
            downloadManager.removeDownload(task)
        }
    }
}
