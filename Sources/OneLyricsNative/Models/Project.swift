import Foundation

struct LyricBlock: Identifiable, Codable {
    var id: UUID = UUID()
    var text: String
    var startMs: Double
    var endMs: Double
}

struct TypographyConfig: Codable {
    var fontFamily: String = "Inter"
    var fontSize: CGFloat = 64
    var color: String = "#ffffff" // Hex
    var glow: CGFloat = 10
}

struct ProjectState: Codable {
    var title: String = "Untitled Project"
    var audioURL: URL?
    var backgroundURL: URL?
    var durationMs: Double = 0
    var fps: Double = 30
    var lyrics: [LyricBlock] = []
    var templateId: String = "CleanMusicChannel"
    var typography: TypographyConfig = TypographyConfig()
}
