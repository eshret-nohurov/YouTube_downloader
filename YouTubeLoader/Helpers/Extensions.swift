import SwiftUI

extension Color {
    static let accentGradient = LinearGradient(
        colors: [.blue, .purple],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension URL {
    var shortPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = self.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(.regularMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }
}
