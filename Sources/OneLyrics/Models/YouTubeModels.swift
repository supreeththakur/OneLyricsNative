import Foundation

// MARK: - YouTube Channel

struct YouTubeChannel: Codable {
    var channelId: String
    var channelName: String
    var profileImageURL: String?
    var subscriberCount: String?
    var isConnected: Bool = true
}

// MARK: - Upload Status

enum YouTubeUploadStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case ready = "Ready"
    case queued = "Queued"
    case uploading = "Uploading"
    case processing = "Processing"
    case scheduled = "Scheduled"
    case published = "Published"
    case failed = "Failed"
    case cancelled = "Cancelled"
    
    var color: String {
        switch self {
        case .draft: return "#888888"
        case .ready: return "#4ECDC4"
        case .queued: return "#FFD93D"
        case .uploading: return "#6C63FF"
        case .processing: return "#FF6B6B"
        case .scheduled: return "#45B7D1"
        case .published: return "#2ECC71"
        case .failed: return "#E74C3C"
        case .cancelled: return "#95A5A6"
        }
    }
    
    var icon: String {
        switch self {
        case .draft: return "doc.text"
        case .ready: return "checkmark.circle"
        case .queued: return "clock.arrow.circlepath"
        case .uploading: return "arrow.up.circle"
        case .processing: return "gearshape.2"
        case .scheduled: return "calendar.badge.clock"
        case .published: return "globe"
        case .failed: return "exclamationmark.triangle"
        case .cancelled: return "xmark.circle"
        }
    }
}

// MARK: - YouTube Video Category

enum YouTubeCategory: String, Codable, CaseIterable {
    case music = "10"
    case entertainment = "24"
    case peopleBlogs = "22"
    case education = "27"
    case howtoStyle = "26"
    case scienceTech = "28"
    
    var displayName: String {
        switch self {
        case .music: return "Music"
        case .entertainment: return "Entertainment"
        case .peopleBlogs: return "People & Blogs"
        case .education: return "Education"
        case .howtoStyle: return "Howto & Style"
        case .scienceTech: return "Science & Technology"
        }
    }
}

// MARK: - YouTube Visibility

enum YouTubeVisibility: String, Codable, CaseIterable {
    case `public` = "public"
    case unlisted = "unlisted"
    case `private` = "private"
    
    var displayName: String {
        switch self {
        case .public: return "Public"
        case .unlisted: return "Unlisted"
        case .private: return "Private"
        }
    }
    
    var icon: String {
        switch self {
        case .public: return "globe"
        case .unlisted: return "link"
        case .private: return "lock"
        }
    }
}

// MARK: - YouTube Playlist

struct YouTubePlaylist: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var itemCount: Int = 0
}

// MARK: - Upload Queue Item

struct YouTubeQueueItem: Codable, Identifiable {
    var id: UUID = UUID()
    var projectId: UUID
    var videoFileURL: String // Path to rendered video
    var thumbnailFileURL: String? // Path to thumbnail
    
    // Metadata
    var title: String = ""
    var description: String = ""
    var tags: [String] = []
    var category: YouTubeCategory = .music
    var visibility: YouTubeVisibility = .public
    var playlistId: String?
    var playlistTitle: String?
    
    // Scheduling
    var scheduledDate: Date?
    var timezone: String = TimeZone.current.identifier
    
    // Status
    var status: YouTubeUploadStatus = .draft
    var youtubeVideoId: String?
    var youtubeVideoURL: String?
    var uploadProgress: Double = 0
    var uploadSpeed: String?
    var remainingTime: String?
    var errorMessage: String?
    
    // Timestamps
    var createdAt: Date = Date()
    var lastModified: Date = Date()
    var publishedAt: Date?
    
    // Queue ordering
    var queueOrder: Int = 0
}

// MARK: - Recurring Schedule Rule

struct RecurringScheduleRule: Codable, Identifiable {
    var id: UUID = UUID()
    var dayOfWeek: Int // 1=Sunday, 2=Monday, ..., 7=Saturday
    var hour: Int = 19
    var minute: Int = 0
    var timezone: String = TimeZone.current.identifier
    var isEnabled: Bool = true
    
    var dayName: String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[(dayOfWeek - 1) % 7]
    }
    
    var timeString: String {
        let h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let ampm = hour >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", h, minute, ampm)
    }
}

// MARK: - Title Template

struct YouTubeTitleTemplate: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = "Default"
    var format: String = "{Artist} - {Song} (Lyrics)"
    var isDefault: Bool = false
}

// MARK: - Description Template

struct YouTubeDescriptionTemplate: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = "Default"
    var format: String = """
    {Artist} - {Song} (Lyrics)
    
    🎵 {Artist} - {Song}
    📀 Album: {Album}
    📅 Released: {Year}
    
    ──────────────────
    
    🎶 Lyrics:
    {Lyrics}
    
    ──────────────────
    
    📌 Follow {Artist}:
    {ArtistLinks}
    
    🔗 Listen:
    {SpotifyLink}
    
    ──────────────────
    
    ⚠️ Copyright Disclaimer:
    {Copyright}
    
    📌 Created with OneLyrics
    """
    var isDefault: Bool = false
}

// MARK: - Tag Preset

struct YouTubeTagPreset: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = "Default"
    var tags: [String] = []
    var isDefault: Bool = false
}

// MARK: - Publishing Settings (Persisted)

struct YouTubePublishingSettings: Codable {
    var channel: YouTubeChannel?
    var accessToken: String?
    var refreshToken: String?
    var tokenExpiry: Date?
    var titleTemplates: [YouTubeTitleTemplate] = [
        YouTubeTitleTemplate(name: "Lyrics", format: "{Artist} - {Song} (Lyrics)", isDefault: true),
        YouTubeTitleTemplate(name: "Lyric Video", format: "{Artist} - {Song} | Lyric Video"),
        YouTubeTitleTemplate(name: "With Album", format: "{Artist} - {Song} ({Album}) [Lyrics]")
    ]
    var descriptionTemplates: [YouTubeDescriptionTemplate] = [
        YouTubeDescriptionTemplate(name: "Standard", format: """
        {Artist} - {Song} (Lyrics)
        
        🎵 {Artist} - {Song}
        📀 Album: {Album}
        📅 Released: {Year}
        
        ──────────────────
        
        📌 Created with OneLyrics
        """, isDefault: true)
    ]
    var tagPresets: [YouTubeTagPreset] = [
        YouTubeTagPreset(name: "Lyrics Video", tags: ["lyrics", "lyric video", "lyrics video"], isDefault: true)
    ]
    var defaultPlaylistId: String?
    var defaultVisibility: YouTubeVisibility = .public
    var defaultCategory: YouTubeCategory = .music
    var defaultTimezone: String = TimeZone.current.identifier
    var recurringRules: [RecurringScheduleRule] = []
}

// MARK: - Project Metadata (for template variable substitution)

struct ProjectMetadata {
    var artist: String = ""
    var song: String = ""
    var album: String = ""
    var year: String = ""
    var spotifyLink: String = ""
    var artistLinks: String = ""
    var copyright: String = ""
    var lyrics: String = ""
    
    /// Parses title into artist + song (assumes "Artist - Song" format)
    static func fromProjectState(_ state: ProjectState) -> ProjectMetadata {
        var meta = ProjectMetadata()
        let title = state.title
        
        if title.contains(" - ") {
            let parts = title.components(separatedBy: " - ")
            meta.artist = parts[0].trimmingCharacters(in: .whitespaces)
            meta.song = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
        } else {
            meta.song = title
        }
        
        // Build lyrics text from blocks
        meta.lyrics = state.lyrics.map { $0.text }.joined(separator: "\n")
        meta.copyright = "All rights belong to their respective owners."
        
        return meta
    }
    
    func applyToTemplate(_ template: String) -> String {
        var result = template
        result = result.replacingOccurrences(of: "{Artist}", with: artist)
        result = result.replacingOccurrences(of: "{Song}", with: song)
        result = result.replacingOccurrences(of: "{Album}", with: album.isEmpty ? "Unknown" : album)
        result = result.replacingOccurrences(of: "{Year}", with: year.isEmpty ? String(Calendar.current.component(.year, from: Date())) : year)
        result = result.replacingOccurrences(of: "{SpotifyLink}", with: spotifyLink.isEmpty ? "" : spotifyLink)
        result = result.replacingOccurrences(of: "{ArtistLinks}", with: artistLinks.isEmpty ? "" : artistLinks)
        result = result.replacingOccurrences(of: "{Copyright}", with: copyright)
        result = result.replacingOccurrences(of: "{Lyrics}", with: lyrics)
        return result
    }
}
