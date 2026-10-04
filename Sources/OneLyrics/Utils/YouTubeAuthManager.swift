import Foundation
import AppKit
import AuthenticationServices

// MARK: - YouTube Auth Manager

class YouTubeAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = YouTubeAuthManager()
    
    // Google OAuth Configuration
    // Users need to set up their own Google Cloud Console project
    // and replace these with their own credentials
    private let clientId = "YOUR_GOOGLE_CLIENT_ID"
    private let clientSecret = "YOUR_GOOGLE_CLIENT_SECRET"
    private let redirectURI = "com.onelyrics.app:/oauth2redirect"
    private let scopes = [
        "https://www.googleapis.com/auth/youtube",
        "https://www.googleapis.com/auth/youtube.upload",
        "https://www.googleapis.com/auth/youtube.force-ssl"
    ].joined(separator: " ")
    
    @Published var isAuthenticated: Bool = false
    @Published var channel: YouTubeChannel?
    @Published var isAuthenticating: Bool = false
    @Published var authError: String?
    
    private var settings: YouTubePublishingSettings
    
    private var settingsURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("OneLyrics/YouTube", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent("youtube_settings.json")
    }
    
    override init() {
        self.settings = YouTubePublishingSettings()
        super.init()
        loadSettings()
    }
    
    // MARK: - Settings Persistence
    
    func loadSettings() {
        if let data = try? Data(contentsOf: settingsURL),
           let loaded = try? JSONDecoder().decode(YouTubePublishingSettings.self, from: data) {
            self.settings = loaded
            self.channel = loaded.channel
            self.isAuthenticated = loaded.channel != nil && loaded.refreshToken != nil
        }
    }
    
    func saveSettings() {
        settings.channel = channel
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsURL)
        }
    }
    
    func getSettings() -> YouTubePublishingSettings {
        return settings
    }
    
    func updateSettings(_ newSettings: YouTubePublishingSettings) {
        self.settings = newSettings
        saveSettings()
    }
    
    // MARK: - OAuth Flow
    
    func authenticate() {
        isAuthenticating = true
        authError = nil
        
        guard clientId != "YOUR_GOOGLE_CLIENT_ID" else {
            // Demo mode - simulate authentication for development
            simulateAuth()
            return
        }
        
        let authURLString = "https://accounts.google.com/o/oauth2/v2/auth"
            + "?client_id=\(clientId)"
            + "&redirect_uri=\(redirectURI)"
            + "&response_type=code"
            + "&scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopes)"
            + "&access_type=offline"
            + "&prompt=consent"
        
        guard let authURL = URL(string: authURLString) else {
            isAuthenticating = false
            authError = "Invalid authentication URL"
            return
        }
        
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "com.onelyrics.app") { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAuthenticating = false
                
                if let error = error {
                    self.authError = error.localizedDescription
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    self.authError = "Failed to get authorization code"
                    return
                }
                
                self.exchangeCodeForToken(code: code)
            }
        }
        
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }
    
    private func exchangeCodeForToken(code: String) {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "code=\(code)"
            + "&client_id=\(clientId)"
            + "&client_secret=\(clientSecret)"
            + "&redirect_uri=\(redirectURI)"
            + "&grant_type=authorization_code"
        
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.authError = error.localizedDescription
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.authError = "Failed to parse token response"
                    return
                }
                
                if let accessToken = json["access_token"] as? String {
                    self.settings.accessToken = accessToken
                    self.settings.refreshToken = json["refresh_token"] as? String ?? self.settings.refreshToken
                    
                    if let expiresIn = json["expires_in"] as? Int {
                        self.settings.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
                    }
                    
                    self.saveSettings()
                    self.fetchChannelInfo()
                } else {
                    self.authError = json["error_description"] as? String ?? "Authentication failed"
                }
            }
        }.resume()
    }
    
    // MARK: - Token Refresh
    
    func refreshTokenIfNeeded(completion: @escaping (String?) -> Void) {
        // Check if token is still valid
        if let expiry = settings.tokenExpiry, expiry > Date().addingTimeInterval(60),
           let token = settings.accessToken {
            completion(token)
            return
        }
        
        guard let refreshToken = settings.refreshToken else {
            completion(nil)
            return
        }
        
        // Demo mode
        if clientId == "YOUR_GOOGLE_CLIENT_ID" {
            completion("demo_token")
            return
        }
        
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "client_id=\(clientId)"
            + "&client_secret=\(clientSecret)"
            + "&refresh_token=\(refreshToken)"
            + "&grant_type=refresh_token"
        
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let accessToken = json["access_token"] as? String else {
                    completion(nil)
                    return
                }
                
                self.settings.accessToken = accessToken
                if let expiresIn = json["expires_in"] as? Int {
                    self.settings.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
                }
                self.saveSettings()
                completion(accessToken)
            }
        }.resume()
    }
    
    // MARK: - Channel Info
    
    func fetchChannelInfo() {
        refreshTokenIfNeeded { [weak self] token in
            guard let self = self, let token = token else { return }
            
            // Demo mode
            if self.clientId == "YOUR_GOOGLE_CLIENT_ID" {
                return
            }
            
            let url = URL(string: "https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics&mine=true")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
                DispatchQueue.main.async {
                    guard let self = self, let data = data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let items = json["items"] as? [[String: Any]],
                          let item = items.first else { return }
                    
                    let snippet = item["snippet"] as? [String: Any] ?? [:]
                    let statistics = item["statistics"] as? [String: Any] ?? [:]
                    let thumbnails = snippet["thumbnails"] as? [String: Any] ?? [:]
                    let defaultThumb = thumbnails["default"] as? [String: Any] ?? [:]
                    
                    self.channel = YouTubeChannel(
                        channelId: item["id"] as? String ?? "",
                        channelName: snippet["title"] as? String ?? "My Channel",
                        profileImageURL: defaultThumb["url"] as? String,
                        subscriberCount: statistics["subscriberCount"] as? String,
                        isConnected: true
                    )
                    self.isAuthenticated = true
                    self.saveSettings()
                }
            }.resume()
        }
    }
    
    // MARK: - Demo/Simulate Auth
    
    private func simulateAuth() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.channel = YouTubeChannel(
                channelId: "demo_channel",
                channelName: "OneLyrics Demo Channel",
                profileImageURL: nil,
                subscriberCount: "1,234",
                isConnected: true
            )
            self.isAuthenticated = true
            self.settings.accessToken = "demo_token"
            self.settings.refreshToken = "demo_refresh"
            self.settings.tokenExpiry = Date().addingTimeInterval(3600)
            self.isAuthenticating = false
            self.saveSettings()
        }
    }
    
    // MARK: - Disconnect
    
    func disconnect() {
        channel = nil
        isAuthenticated = false
        settings.accessToken = nil
        settings.refreshToken = nil
        settings.tokenExpiry = nil
        settings.channel = nil
        saveSettings()
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
    }
}
