import Foundation

enum ProjectType: String, Codable, CaseIterable {
    case lyrics = "Lyrics"
    case visualizer = "Visualizer"
}

enum VisualizerType: String, Codable, CaseIterable {
    case waveform = "Waveform"
    case spectrumBars = "Spectrum Bars"
    case circular = "Circular"
    case frequencyReactive = "Frequency Reactive"
}

enum VisualizerPreset: String, Codable, CaseIterable {
    case cinematic = "Cinematic"
    case minimal = "Minimal"
    case electronic = "Electronic"
    case retro = "Retro"
    case atmospheric = "Atmospheric"
    case custom = "Custom"
}

struct VisualizerTextOverlay: Codable {
    var title: String = ""
    var artist: String = ""
    var customText: String = ""
    var showTitle: Bool = true
    var showArtist: Bool = true
    var showCustomText: Bool = false
    var positionX: Double = 0.5
    var positionY: Double = 0.8
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        artist = try container.decodeIfPresent(String.self, forKey: .artist) ?? ""
        customText = try container.decodeIfPresent(String.self, forKey: .customText) ?? ""
        showTitle = try container.decodeIfPresent(Bool.self, forKey: .showTitle) ?? true
        showArtist = try container.decodeIfPresent(Bool.self, forKey: .showArtist) ?? true
        showCustomText = try container.decodeIfPresent(Bool.self, forKey: .showCustomText) ?? false
        positionX = try container.decodeIfPresent(Double.self, forKey: .positionX) ?? 0.5
        positionY = try container.decodeIfPresent(Double.self, forKey: .positionY) ?? 0.8
    }
}

struct VisualizerConfig: Codable {
    var type: VisualizerType = .spectrumBars
    var preset: VisualizerPreset = .minimal
    var color1: String = "#ff00ff"
    var color2: String = "#00ffff"
    var glowIntensity: Double = 1.0
    var particlesEnabled: Bool = false
    var particleCount: Int = 50
    var motionIntensity: Double = 1.0
    var textOverlay: VisualizerTextOverlay = VisualizerTextOverlay()
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(VisualizerType.self, forKey: .type) ?? .spectrumBars
        preset = try container.decodeIfPresent(VisualizerPreset.self, forKey: .preset) ?? .minimal
        color1 = try container.decodeIfPresent(String.self, forKey: .color1) ?? "#ff00ff"
        color2 = try container.decodeIfPresent(String.self, forKey: .color2) ?? "#00ffff"
        glowIntensity = try container.decodeIfPresent(Double.self, forKey: .glowIntensity) ?? 1.0
        particlesEnabled = try container.decodeIfPresent(Bool.self, forKey: .particlesEnabled) ?? false
        particleCount = try container.decodeIfPresent(Int.self, forKey: .particleCount) ?? 50
        motionIntensity = try container.decodeIfPresent(Double.self, forKey: .motionIntensity) ?? 1.0
        textOverlay = try container.decodeIfPresent(VisualizerTextOverlay.self, forKey: .textOverlay) ?? VisualizerTextOverlay()
    }
}

struct LyricBlock: Identifiable, Codable {
    var id: UUID = UUID()
    var text: String
    var transliteratedText: String?
    var isTransliteratedActive: Bool = false
    var startMs: Double
    var endMs: Double
    
    var displayText: String {
        return isTransliteratedActive ? (transliteratedText ?? text) : text
    }
    
    init(id: UUID = UUID(), text: String, transliteratedText: String? = nil, isTransliteratedActive: Bool = false, startMs: Double, endMs: Double) {
        self.id = id
        self.text = text
        self.transliteratedText = transliteratedText
        self.isTransliteratedActive = isTransliteratedActive
        self.startMs = startMs
        self.endMs = endMs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try container.decode(String.self, forKey: .text)
        transliteratedText = try container.decodeIfPresent(String.self, forKey: .transliteratedText)
        isTransliteratedActive = try container.decodeIfPresent(Bool.self, forKey: .isTransliteratedActive) ?? false
        startMs = try container.decode(Double.self, forKey: .startMs)
        endMs = try container.decode(Double.self, forKey: .endMs)
    }
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
    var glowColor: String?
    var hasStroke: Bool = false
    var strokeWidth: CGFloat = 3.0
    var strokeColor: String = "#000000"
    var animationStyle: AnimationStyle = .fade
    var alignment: TextAlignmentStyle = .center
    var edgePadding: CGFloat = 80.0
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily) ?? "Inter"
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? 150
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#ffffff"
        glow = try container.decodeIfPresent(CGFloat.self, forKey: .glow) ?? 20
        glowColor = try container.decodeIfPresent(String.self, forKey: .glowColor)
        hasStroke = try container.decodeIfPresent(Bool.self, forKey: .hasStroke) ?? false
        strokeWidth = try container.decodeIfPresent(CGFloat.self, forKey: .strokeWidth) ?? 3.0
        strokeColor = try container.decodeIfPresent(String.self, forKey: .strokeColor) ?? "#000000"
        animationStyle = try container.decodeIfPresent(AnimationStyle.self, forKey: .animationStyle) ?? .fade
        alignment = try container.decodeIfPresent(TextAlignmentStyle.self, forKey: .alignment) ?? .center
        edgePadding = try container.decodeIfPresent(CGFloat.self, forKey: .edgePadding) ?? 80.0
    }
}

struct MediaConfig: Codable {
    var volume: Float = 1.0
    var bgVolume: Float = 0.0
    var brightness: Double = 0.0
    var contrast: Double = 1.0
    var saturation: Double = 1.0
    var cropScale: Double = 1.0
    var cropOffsetX: Double = 0.0
    var cropOffsetY: Double = 0.0
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        volume = try container.decodeIfPresent(Float.self, forKey: .volume) ?? 1.0
        bgVolume = try container.decodeIfPresent(Float.self, forKey: .bgVolume) ?? 0.0
        brightness = try container.decodeIfPresent(Double.self, forKey: .brightness) ?? 0.0
        contrast = try container.decodeIfPresent(Double.self, forKey: .contrast) ?? 1.0
        saturation = try container.decodeIfPresent(Double.self, forKey: .saturation) ?? 1.0
        cropScale = try container.decodeIfPresent(Double.self, forKey: .cropScale) ?? 1.0
        cropOffsetX = try container.decodeIfPresent(Double.self, forKey: .cropOffsetX) ?? 0.0
        cropOffsetY = try container.decodeIfPresent(Double.self, forKey: .cropOffsetY) ?? 0.0
    }
}

struct ProjectState: Codable, Identifiable {
    var id: UUID = UUID()
    var type: ProjectType = .lyrics
    var title: String = "Untitled Project"
    var createdAt: Date = Date()
    var lastModified: Date = Date()
    var audioURL: URL?
    var backgroundURL: URL?
    var coverImageURL: URL?
    var durationMs: Double = 0
    var fps: Double = 30
    var lyrics: [LyricBlock] = []
    var templateId: String
    var typography: TypographyConfig
    var mediaConfig: MediaConfig = MediaConfig()
    var visualizerConfig: VisualizerConfig = VisualizerConfig()
    var enableAutoTransliteration: Bool = true
    var showTransliteratedLyrics: Bool = true
    
    init() {
        let defId = TemplateManager.defaultTemplate
        self.templateId = defId
        var conf = TypographyConfig()
        TemplateManager.applyTemplate(defId, to: &conf)
        self.typography = conf
        self.createdAt = Date()
        self.lastModified = Date()
        self.enableAutoTransliteration = true
        self.showTransliteratedLyrics = true
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        type = try container.decodeIfPresent(ProjectType.self, forKey: .type) ?? .lyrics
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Project"
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? lastModified
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
        backgroundURL = try container.decodeIfPresent(URL.self, forKey: .backgroundURL)
        coverImageURL = try container.decodeIfPresent(URL.self, forKey: .coverImageURL)
        durationMs = try container.decodeIfPresent(Double.self, forKey: .durationMs) ?? 0
        fps = try container.decodeIfPresent(Double.self, forKey: .fps) ?? 30
        lyrics = try container.decodeIfPresent([LyricBlock].self, forKey: .lyrics) ?? []
        templateId = try container.decodeIfPresent(String.self, forKey: .templateId) ?? TemplateManager.defaultTemplate
        typography = try container.decodeIfPresent(TypographyConfig.self, forKey: .typography) ?? TypographyConfig()
        mediaConfig = try container.decodeIfPresent(MediaConfig.self, forKey: .mediaConfig) ?? MediaConfig()
        visualizerConfig = try container.decodeIfPresent(VisualizerConfig.self, forKey: .visualizerConfig) ?? VisualizerConfig()
        enableAutoTransliteration = try container.decodeIfPresent(Bool.self, forKey: .enableAutoTransliteration) ?? true
        showTransliteratedLyrics = try container.decodeIfPresent(Bool.self, forKey: .showTransliteratedLyrics) ?? true
    }
}
