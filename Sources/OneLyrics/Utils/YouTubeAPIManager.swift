import Foundation
import AppKit

// MARK: - YouTube API Manager

class YouTubeAPIManager: ObservableObject {
    static let shared = YouTubeAPIManager()
    
    @Published var playlists: [YouTubePlaylist] = []
    @Published var isLoadingPlaylists: Bool = false
    
    private let auth = YouTubeAuthManager.shared
    
    // MARK: - Fetch Playlists
    
    func fetchPlaylists() {
        isLoadingPlaylists = true
        
        auth.refreshTokenIfNeeded { [weak self] token in
            guard let self = self, let token = token else {
                DispatchQueue.main.async { self?.isLoadingPlaylists = false }
                return
            }
            
            // Demo mode
            if token == "demo_token" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.playlists = [
                        YouTubePlaylist(id: "pl_1", title: "English Lyrics", itemCount: 42),
                        YouTubePlaylist(id: "pl_2", title: "Hindi Lyrics", itemCount: 28),
                        YouTubePlaylist(id: "pl_3", title: "Pop Songs", itemCount: 15),
                        YouTubePlaylist(id: "pl_4", title: "Trending", itemCount: 8)
                    ]
                    self.isLoadingPlaylists = false
                }
                return
            }
            
            let url = URL(string: "https://www.googleapis.com/youtube/v3/playlists?part=snippet,contentDetails&mine=true&maxResults=50")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isLoadingPlaylists = false
                    
                    guard let data = data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let items = json["items"] as? [[String: Any]] else { return }
                    
                    self.playlists = items.compactMap { item in
                        guard let id = item["id"] as? String,
                              let snippet = item["snippet"] as? [String: Any],
                              let title = snippet["title"] as? String else { return nil }
                        let contentDetails = item["contentDetails"] as? [String: Any]
                        let count = contentDetails?["itemCount"] as? Int ?? 0
                        return YouTubePlaylist(id: id, title: title, itemCount: count)
                    }
                }
            }.resume()
        }
    }
    
    // MARK: - Upload Video (Resumable)
    
    func uploadVideo(
        item: YouTubeQueueItem,
        onProgress: @escaping (Double, String, String) -> Void,
        onComplete: @escaping (String?, String?) -> Void
    ) {
        auth.refreshTokenIfNeeded { [weak self] token in
            guard let self = self, let token = token else {
                onComplete(nil, "Not authenticated")
                return
            }
            
            let videoURL = URL(fileURLWithPath: item.videoFileURL)
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                onComplete(nil, "Video file not found: \(item.videoFileURL)")
                return
            }
            
            // Demo mode
            if token == "demo_token" {
                self.simulateUpload(item: item, onProgress: onProgress, onComplete: onComplete)
                return
            }
            
            // Step 1: Initiate resumable upload
            self.initiateResumableUpload(token: token, item: item) { uploadURL in
                guard let uploadURL = uploadURL else {
                    onComplete(nil, "Failed to initiate upload")
                    return
                }
                
                // Step 2: Upload the file
                self.performResumableUpload(
                    uploadURL: uploadURL,
                    videoURL: videoURL,
                    token: token,
                    onProgress: onProgress,
                    onComplete: onComplete
                )
            }
        }
    }
    
    private func initiateResumableUpload(
        token: String,
        item: YouTubeQueueItem,
        completion: @escaping (URL?) -> Void
    ) {
        let url = URL(string: "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build metadata
        let snippet: [String: Any] = [
            "title": item.title,
            "description": item.description,
            "tags": item.tags,
            "categoryId": item.category.rawValue
        ]
        
        var status: [String: Any] = [:]
        
        if let scheduledDate = item.scheduledDate {
            status["privacyStatus"] = "private"
            let formatter = ISO8601DateFormatter()
            status["publishAt"] = formatter.string(from: scheduledDate)
        } else {
            status["privacyStatus"] = item.visibility.rawValue
        }
        
        let metadata: [String: Any] = [
            "snippet": snippet,
            "status": status
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: metadata)
        
        // Get file size
        let videoURL = URL(fileURLWithPath: item.videoFileURL)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: videoURL.path))?[.size] as? Int64 ?? 0
        request.setValue("video/*", forHTTPHeaderField: "X-Upload-Content-Type")
        request.setValue("\(fileSize)", forHTTPHeaderField: "X-Upload-Content-Length")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               let location = httpResponse.value(forHTTPHeaderField: "Location"),
               let uploadURL = URL(string: location) {
                completion(uploadURL)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    private func performResumableUpload(
        uploadURL: URL,
        videoURL: URL,
        token: String,
        onProgress: @escaping (Double, String, String) -> Void,
        onComplete: @escaping (String?, String?) -> Void
    ) {
        guard let videoData = try? Data(contentsOf: videoURL) else {
            onComplete(nil, "Failed to read video file")
            return
        }
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("video/*", forHTTPHeaderField: "Content-Type")
        request.setValue("\(videoData.count)", forHTTPHeaderField: "Content-Length")
        
        let startTime = Date()
        
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
        let task = session.uploadTask(with: request, from: videoData) { data, response, error in
            if let error = error {
                onComplete(nil, error.localizedDescription)
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let videoId = json["id"] as? String else {
                onComplete(nil, "Failed to parse upload response")
                return
            }
            
            onComplete(videoId, nil)
        }
        
        // Progress tracking via observation
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let speed = Double(videoData.count) * progress.fractionCompleted / elapsed
            let speedStr = self.formatSpeed(speed)
            
            let remaining = elapsed / max(progress.fractionCompleted, 0.001) * (1.0 - progress.fractionCompleted)
            let remainStr = self.formatTime(remaining)
            
            DispatchQueue.main.async {
                onProgress(progress.fractionCompleted, speedStr, remainStr)
            }
        }
        
        // Retain observation by associating it with the task
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        task.resume()
    }
    
    // MARK: - Set Thumbnail
    
    func setThumbnail(videoId: String, thumbnailURL: URL, completion: @escaping (Bool, String?) -> Void) {
        auth.refreshTokenIfNeeded { token in
            guard let token = token else {
                completion(false, "Not authenticated")
                return
            }
            
            // Demo mode
            if token == "demo_token" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completion(true, nil)
                }
                return
            }
            
            let url = URL(string: "https://www.googleapis.com/upload/youtube/v3/thumbnails/set?videoId=\(videoId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            
            guard let imageData = try? Data(contentsOf: thumbnailURL) else {
                completion(false, "Failed to read thumbnail file")
                return
            }
            
            URLSession.shared.uploadTask(with: request, from: imageData) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        completion(true, nil)
                    }
                }
            }.resume()
        }
    }
    
    // MARK: - Add to Playlist
    
    func addToPlaylist(videoId: String, playlistId: String, completion: @escaping (Bool, String?) -> Void) {
        auth.refreshTokenIfNeeded { token in
            guard let token = token else {
                completion(false, "Not authenticated")
                return
            }
            
            // Demo mode
            if token == "demo_token" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    completion(true, nil)
                }
                return
            }
            
            let url = URL(string: "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "snippet": [
                    "playlistId": playlistId,
                    "resourceId": [
                        "kind": "youtube#video",
                        "videoId": videoId
                    ]
                ]
            ]
            
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        completion(true, nil)
                    }
                }
            }.resume()
        }
    }
    
    // MARK: - Update Video Metadata
    
    func updateVideoMetadata(videoId: String, title: String, description: String, tags: [String], category: YouTubeCategory, completion: @escaping (Bool, String?) -> Void) {
        auth.refreshTokenIfNeeded { token in
            guard let token = token else {
                completion(false, "Not authenticated")
                return
            }
            
            // Demo mode
            if token == "demo_token" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    completion(true, nil)
                }
                return
            }
            
            let url = URL(string: "https://www.googleapis.com/youtube/v3/videos?part=snippet")!
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "id": videoId,
                "snippet": [
                    "title": title,
                    "description": description,
                    "tags": tags,
                    "categoryId": category.rawValue
                ]
            ]
            
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        completion(true, nil)
                    }
                }
            }.resume()
        }
    }
    
    // MARK: - Check Video Status
    
    func checkVideoStatus(videoId: String, completion: @escaping (YouTubeUploadStatus?) -> Void) {
        auth.refreshTokenIfNeeded { token in
            guard let token = token else {
                completion(nil)
                return
            }
            
            // Demo mode
            if token == "demo_token" {
                completion(.published)
                return
            }
            
            let url = URL(string: "https://www.googleapis.com/youtube/v3/videos?part=status,processingDetails&id=\(videoId)")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, _, error in
                DispatchQueue.main.async {
                    guard let data = data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let items = json["items"] as? [[String: Any]],
                          let item = items.first,
                          let status = item["status"] as? [String: Any] else {
                        completion(nil)
                        return
                    }
                    
                    let uploadStatus = status["uploadStatus"] as? String ?? ""
                    let privacyStatus = status["privacyStatus"] as? String ?? ""
                    
                    switch uploadStatus {
                    case "processing":
                        completion(.processing)
                    case "uploaded":
                        if privacyStatus == "private" {
                            completion(.scheduled)
                        } else {
                            completion(.published)
                        }
                    case "failed":
                        completion(.failed)
                    default:
                        completion(.published)
                    }
                }
            }.resume()
        }
    }
    
    // MARK: - Demo Upload Simulation
    
    private func simulateUpload(
        item: YouTubeQueueItem,
        onProgress: @escaping (Double, String, String) -> Void,
        onComplete: @escaping (String?, String?) -> Void
    ) {
        let totalSteps = 50
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            currentStep += 1
            let progress = Double(currentStep) / Double(totalSteps)
            let speed = "12.5 MB/s"
            let remaining = "\(max(1, (totalSteps - currentStep) / 10))s"
            
            DispatchQueue.main.async {
                onProgress(min(progress, 1.0), speed, remaining)
            }
            
            if currentStep >= totalSteps {
                timer.invalidate()
                DispatchQueue.main.async {
                    let demoId = "demo_\(UUID().uuidString.prefix(8))"
                    onComplete(demoId, nil)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond > 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond > 1_000 {
            return String(format: "%.0f KB/s", bytesPerSecond / 1_000)
        }
        return String(format: "%.0f B/s", bytesPerSecond)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        if seconds > 3600 {
            return String(format: "%dh %dm", Int(seconds) / 3600, (Int(seconds) % 3600) / 60)
        } else if seconds > 60 {
            return String(format: "%dm %ds", Int(seconds) / 60, Int(seconds) % 60)
        }
        return String(format: "%ds", Int(seconds))
    }
}
