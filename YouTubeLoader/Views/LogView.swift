import SwiftUI

struct LogView: View {
    @EnvironmentObject var telemetry: TelemetryService
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedLevel: LogLevel? = nil

    private var filteredEntries: [LogEntry] {
        var entries = telemetry.entries

        if let level = selectedLevel {
            entries = entries.filter { $0.level == level }
        }

        if !searchText.isEmpty {
            entries = entries.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                ($0.details?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return entries.reversed()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            header
            Divider()

            // Фильтры
            filterBar
            Divider()

            // Список записей
            if filteredEntries.isEmpty {
                emptyState
            } else {
                logList
            }

            Divider()

            // Нижняя панель
            footer
        }
        .frame(width: 700, height: 500)
    }

    // MARK: - Заголовок

    private var header: some View {
        HStack {
            Label("Журнал событий", systemImage: "doc.text.magnifyingglass")
                .font(.headline)

            Spacer()

            Text("\(telemetry.entries.count) записей")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary)
                .cornerRadius(4)

            Button("Закрыть") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(16)
    }

    // MARK: - Фильтры

    private var filterBar: some View {
        HStack(spacing: 10) {
            // Поиск
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Поиск...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(.quaternary)
            .cornerRadius(6)

            // Фильтр по уровню
            Picker("Уровень", selection: $selectedLevel) {
                Text("Все").tag(nil as LogLevel?)
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Label(level.rawValue, systemImage: level.icon)
                        .tag(Optional(level))
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Список

    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredEntries) { entry in
                    logRow(entry)
                }
            }
            .padding(8)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Время
            Text(entry.formattedTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 85, alignment: .leading)

            // Уровень
            levelBadge(entry.level)

            // Категория
            Text(entry.category)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            // Сообщение
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.subheadline)
                    .lineLimit(2)

                if let details = entry.details, !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(levelBackground(entry.level))
        .cornerRadius(4)
    }

    private func levelBadge(_ level: LogLevel) -> some View {
        HStack(spacing: 3) {
            Image(systemName: level.icon)
                .font(.caption2)
            Text(level.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(levelColor(level))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(levelColor(level).opacity(0.1))
        .cornerRadius(4)
        .frame(width: 90)
    }

    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .debug: return .gray
        }
    }

    private func levelBackground(_ level: LogLevel) -> Color {
        switch level {
        case .error: return .red.opacity(0.04)
        case .warning: return .orange.opacity(0.03)
        default: return .clear
        }
    }

    // MARK: - Пустое состояние

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "Журнал пуст" : "Ничего не найдено")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Нижняя панель

    private var footer: some View {
        HStack {
            Button(action: {
                NSWorkspace.shared.open(telemetry.logFileLocation.deletingLastPathComponent())
            }) {
                Label("Открыть папку логов", systemImage: "folder")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Spacer()

            Button(action: { telemetry.clearLogs() }) {
                Label("Очистить", systemImage: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)

            Button(action: { copyLogsToClipboard() }) {
                Label("Копировать всё", systemImage: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func copyLogsToClipboard() {
        let text = filteredEntries.map { $0.formattedEntry }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        TelemetryService.shared.log(.info, category: "UI", message: "Логи скопированы в буфер обмена")
    }
}
