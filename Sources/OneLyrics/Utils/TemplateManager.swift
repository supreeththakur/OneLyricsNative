import Foundation

struct TemplateManager {
    static let builtInTemplates = [
        "Clean Music Channel",
        "Cinematic",
        "Neon Synthwave"
    ]
    
    static var templates: [String] {
        var all = builtInTemplates
        all.append(contentsOf: getCustomTemplates().keys.sorted())
        return all
    }
    
    private static let customTemplatesKey = "OneLyricsCustomTemplates"
    private static let defaultTemplateKey = "OneLyricsDefaultTemplate"
    
    static var defaultTemplate: String {
        get {
            return UserDefaults.standard.string(forKey: defaultTemplateKey) ?? "Clean Music Channel"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultTemplateKey)
        }
    }
    
    static func saveTemplate(name: String, config: TypographyConfig) {
        var custom = getCustomTemplates()
        custom[name] = config
        
        if let encoded = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(encoded, forKey: customTemplatesKey)
        }
    }
    
    static func getCustomTemplates() -> [String: TypographyConfig] {
        guard let data = UserDefaults.standard.data(forKey: customTemplatesKey),
              let decoded = try? JSONDecoder().decode([String: TypographyConfig].self, from: data) else {
            return [:]
        }
        return decoded
    }
    
    static func deleteTemplate(name: String) {
        var custom = getCustomTemplates()
        custom.removeValue(forKey: name)
        
        if let encoded = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(encoded, forKey: customTemplatesKey)
        }
        
        // If we deleted the default template, revert to built-in default
        if defaultTemplate == name {
            defaultTemplate = "Clean Music Channel"
        }
    }
    
    static func applyTemplate(_ id: String, to config: inout TypographyConfig) {
        let customTemplates = getCustomTemplates()
        if let customConfig = customTemplates[id] {
            config = customConfig
            return
        }
        
        switch id {
        case "Cinematic":
            config.fontFamily = "Georgia"
            config.fontSize = 100
            config.color = "#ffffff"
            config.glow = 10
            config.animationStyle = .slideUp
            config.alignment = .bottom
        case "Neon Synthwave":
            config.fontFamily = "Courier"
            config.fontSize = 180
            config.color = "#00ffcc"
            config.glow = 50
            config.animationStyle = .pop
            config.alignment = .center
        case "Clean Music Channel":
            fallthrough
        default:
            config.fontFamily = "Inter"
            config.fontSize = 150
            config.color = "#ffffff"
            config.glow = 20
            config.animationStyle = .fade
            config.alignment = .center
        }
    }
}
