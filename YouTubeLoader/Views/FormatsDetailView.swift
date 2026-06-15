import SwiftUI

struct FormatsDetailView: View {
    let videoInfo: VideoInfo
    @Binding var selectedFormat: VideoFormat?
    @Environment(\.dismiss) private var dismiss

    @State private var filter: FormatFilter = .all

    enum FormatFilter: String, CaseIterable {
        case all = "Все"
        case videoAudio = "Видео+Аудио"
        case videoOnly = "Только видео"
        case audioOnly = "Только аудио"
    }

    private var filteredFormats: [VideoFormat] {
        switch filter {
        case .all: return videoInfo.detailedFormats
        case .videoAudio: return videoInfo.detailedFormats.filter { !$0.isAudioOnly && $0.codec.contains("+") }
        case .videoOnly: return videoInfo.detailedFormats.filter { !$0.isAudioOnly && !$0.codec.contains("+") }
        case .audioOnly: return videoInfo.detailedFormats.filter { $0.isAudioOnly }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Все доступные форматы")
                        .font(.headline)
                    Text(videoInfo.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(videoInfo.detailedFormats.count) форматов")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary)
                    .cornerRadius(4)
                Button("Закрыть") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(16)

            Divider()

            // Фильтры
            Picker("", selection: $filter) {
                ForEach(FormatFilter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Заголовок таблицы
            HStack(spacing: 0) {
                Text("Качество")
                    .frame(width: 130, alignment: .leading)
                Text("Формат")
                    .frame(width: 60, alignment: .leading)
                Text("Кодек")
                    .frame(width: 120, alignment: .leading)
                Text("FPS")
                    .frame(width: 45, alignment: .trailing)
                Text("Битрейт")
                    .frame(width: 70, alignment: .trailing)
                Text("Размер")
                    .frame(width: 80, alignment: .trailing)
                Spacer()
            }
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5))

            // Список
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredFormats) { format in
                        formatRow(format)
                        Divider().padding(.leading, 16)
                    }
                }
            }

            Divider()

            // Выбранный
            HStack {
                if let sel = selectedFormat {
                    Text("Выбран: \(sel.quality)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Применить и закрыть") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(width: 640, height: 500)
    }

    private func formatRow(_ format: VideoFormat) -> some View {
        let isSelected = selectedFormat?.id == format.id

        return Button(action: { selectedFormat = format }) {
            HStack(spacing: 0) {
                // Качество
                HStack(spacing: 6) {
                    Image(systemName: format.isAudioOnly ? "waveform" : "film")
                        .font(.caption2)
                        .foregroundStyle(format.isAudioOnly ? .purple : .blue)
                    Text(format.quality)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                .frame(width: 130, alignment: .leading)

                // Формат
                Text(format.ext.uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                // Кодек
                Text(format.codec)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 120, alignment: .leading)

                // FPS
                Text(format.fps != nil ? "\(format.fps!)" : "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 45, alignment: .trailing)

                // Битрейт
                Text(format.bitrate != nil ? "\(format.bitrate!)k" : "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 70, alignment: .trailing)

                // Размер
                Text(format.fileSize != nil
                    ? ByteCountFormatter.string(fromByteCount: format.fileSize!, countStyle: .file)
                    : "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 80, alignment: .trailing)

                Spacer()

                // Чекмарк
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
