import SwiftUI

struct VideoPreviewView: View {
    let videoInfo: VideoInfo
    @Binding var selectedFormat: VideoFormat?
    let downloadFolder: URL
    let onSelectFolder: () -> Void
    let onDownload: () -> Void

    @State private var showAllFormats = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Заголовок
            HStack(spacing: 14) {
                thumbnailView
                videoInfoSection
            }
            .padding(20)

            Divider()
                .padding(.horizontal, 16)

            // Настройки загрузки
            downloadSettings
                .padding(20)

            // Кнопка загрузки
            downloadButton
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .background(.regularMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    // MARK: - Превью

    private var thumbnailView: some View {
        Group {
            if let url = videoInfo.thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    case .failure:
                        placeholderThumb
                    case .empty:
                        ProgressView()
                            .frame(width: 200, height: 112)
                    @unknown default:
                        placeholderThumb
                    }
                }
                .frame(width: 200, height: 112)
                .cornerRadius(8)
                .clipped()
            } else {
                placeholderThumb
            }
        }
    }

    private var placeholderThumb: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .frame(width: 200, height: 112)
            .overlay(
                Image(systemName: "play.rectangle")
                    .font(.title)
                    .foregroundStyle(.tertiary)
            )
    }

    // MARK: - Информация

    private var videoInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(videoInfo.title)
                .font(.headline)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !videoInfo.channel.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.caption)
                    Text(videoInfo.channel)
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(videoInfo.durationString)
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "film")
                        .font(.caption)
                    Text("\(videoInfo.availableFormats.count) форматов")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Настройки

    private var downloadSettings: some View {
        VStack(spacing: 14) {
            // Качество
            HStack {
                Label("Качество", systemImage: "sparkles")
                    .font(.subheadline)
                    .frame(width: 120, alignment: .leading)

                Picker("", selection: $selectedFormat) {
                    ForEach(videoInfo.availableFormats + (
                        // Если выбран детальный формат — добавим его в список
                        selectedFormat.flatMap { sel in
                            videoInfo.availableFormats.contains(sel) ? nil : [sel]
                        } ?? []
                    )) { format in
                        Text(format.displayName)
                            .tag(Optional(format))
                    }
                }
                .labelsHidden()

                Button(action: { showAllFormats = true }) {
                    Image(systemName: "list.bullet.rectangle")
                }
                .help("Все доступные форматы")
                .sheet(isPresented: $showAllFormats) {
                    FormatsDetailView(videoInfo: videoInfo, selectedFormat: $selectedFormat)
                }
            }

            // Папка
            HStack {
                Label("Папка", systemImage: "folder")
                    .font(.subheadline)
                    .frame(width: 120, alignment: .leading)

                HStack(spacing: 8) {
                    Text(downloadFolder.lastPathComponent)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(downloadFolder.path)

                    Spacer()

                    Button("Изменить") {
                        onSelectFolder()
                    }
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Кнопка загрузки

    private var downloadButton: some View {
        Button(action: onDownload) {
            HStack(spacing: 8) {
                Image(systemName: selectedFormat?.isAudioOnly == true
                    ? "music.note"
                    : "arrow.down.circle.fill")
                Text(selectedFormat?.isAudioOnly == true
                    ? "Скачать аудио"
                    : "Скачать видео")
                    .fontWeight(.semibold)
            }
            .font(.body)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(selectedFormat == nil)
    }
}
