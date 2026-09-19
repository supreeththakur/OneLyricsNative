import Foundation

struct LyricBlock: Identifiable, Codable {
    var id: UUID = UUID()
    var text: String
    var startMs: Double
    var endMs: Double
}

enum AnimationStyle: String, Codable, CaseIterable {
    case fade = "Fade"
    case blurFade = "Blur Fade"
    case scaleDown = "Scale Down"
    case scaleUp = "Scale Up"
    case driftUp = "Drift Up"
    case gentleSlide = "Gentle Slide"
    case typewriter = "Typewriter"
    case pop = "Pop"
    case slideUp = "Slide Up"
    case float = "Float"
    case none = "None"
}

enum TextAlignmentStyle: String, Codable, CaseIterable {
    case center = "Center"
    case bottom = "Bottom"
    case top = "Top"
    case bottomLeading = "Bottom Left"
}

struct TypographyConfig: Codable {
    var fontFamily: String = "Inter" // We can fall back to system font if Inter isn't available
    var fontSize: CGFloat = 150
    var color: String = "#ffffff" // Hex
    var glow: CGFloat = 20
    var hasStroke: Bool = false
    var strokeWidth: CGFloat = 3.0
    var strokeColor: String = "#000000"
    var animationStyle: AnimationStyle = .fade
    var alignment: TextAlignmentStyle = .center
}

struct MediaConfig: Codable {
    var volume: Float = 1.0
    var bgVolume: Float = 0.0
    var brightness: Double = 0.0
    var contrast: Double = 1.0
    var saturation: Double = 1.0
    var cropScale: Double = 1.0
}

struct ProjectState: Codable {
    var title: String = "Untitled Project"
    var audioURL: URL?
    var backgroundURL: URL?
    var durationMs: Double = 0
    var fps: Double = 30
    var lyrics: [LyricBlock] = []
    var templateId: String
    var typography: TypographyConfig
    var mediaConfig: MediaConfig = MediaConfig()
    
    init() {
        let defId = TemplateManager.defaultTemplate
        self.templateId = defId
        var conf = TypographyConfig()
        TemplateManager.applyTemplate(defId, to: &conf)
        self.typography = conf
    }
}
