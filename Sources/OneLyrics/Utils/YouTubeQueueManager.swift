import Foundation
import SwiftUI

// MARK: - YouTube Queue Manager

class YouTubeQueueManager: ObservableObject {
    static let shared = YouTubeQueueManager()
    
    @Published var queue: [YouTubeQueueItem] = []
    @Published var isProcessing: Bool = false
    @Published var currentUploadId: UUID?
    
    private let api = YouTubeAPIManager.shared
    private let auth = YouTubeAuthManager.shared
    private var schedulerTimer: Timer?
    
    private var queueURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("OneLyrics/YouTube", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent("upload_queue.json")
    }
    
    init() {
        loadQueue()
        startScheduler()
    }
    
    // MARK: - Persistence
    
    func loadQueue() {
        if let data = try? Data(contentsOf: queueURL),
           let loaded = try? JSONDecoder().decode([YouTubeQueueItem].self, from: data) {
            self.queue = loaded.sorted { $0.queueOrder < $1.queueOrder }
        }
    }
    
    func saveQueue() {
        if let data = try? JSONEncoder().encode(queue) {
            try? data.write(to: queueURL)
        }
    }
    
    // MARK: - Queue Operations
    
    func addToQueue(_ item: YouTubeQueueItem) {
        var newItem = item
        newItem.queueOrder = (queue.map { $0.queueOrder }.max() ?? -1) + 1
        newItem.lastModified = Date()
        queue.append(newItem)
        saveQueue()
    }
    
    func removeFromQueue(id: UUID) {
        queue.removeAll { $0.id == id }
        saveQueue()
    }
    
    func updateItem(id: UUID, update: (inout YouTubeQueueItem) -> Void) {
        if let index = queue.firstIndex(where: { $0.id == id }) {
            update(&queue[index])
            queue[index].lastModified = Date()
            saveQueue()
        }
    }
    
    func reorderQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        for (index, _) in queue.enumerated() {
            queue[index].queueOrder = index
        }
        saveQueue()
    }
    
    func cancelItem(id: UUID) {
        updateItem(id: id) { item in
            item.status = .cancelled
        }
    }
    
    func retryItem(id: UUID) {
        updateItem(id: id) { item in
            item.status = .ready
            item.errorMessage = nil
            item.uploadProgress = 0
        }
    }
    
    // MARK: - Upload Processing
    
    func processNextInQueue() {
        guard !isProcessing else { return }
        guard auth.isAuthenticated else { return }
        
        // Find next ready item
        guard let nextItem = queue.first(where: { $0.status == .ready || $0.status == .queued }) else {
            return
        }
        
        isProcessing = true
        currentUploadId = nextItem.id
        
        updateItem(id: nextItem.id) { item in
            item.status = .uploading
        }
        
        api.uploadVideo(
            item: nextItem,
            onProgress: { [weak self] progress, speed, remaining in
                self?.updateItem(id: nextItem.id) { item in
                    item.uploadProgress = progress
                    item.uploadSpeed = speed
                    item.remainingTime = remaining
                }
            },
            onComplete: { [weak self] videoId, error in
                guard let self = self else { return }
                
                if let videoId = videoId {
                    self.updateItem(id: nextItem.id) { item in
                        item.youtubeVideoId = videoId
                        item.youtubeVideoURL = "https://www.youtube.com/watch?v=\(videoId)"
                        item.uploadProgress = 1.0
                        
                        if item.scheduledDate != nil {
                            item.status = .scheduled
                        } else {
                            item.status = .processing
                        }
                    }
                    
                    // Set thumbnail if available
                    if let thumbPath = nextItem.thumbnailFileURL {
                        let thumbURL = URL(fileURLWithPath: thumbPath)
                        self.api.setThumbnail(videoId: videoId, thumbnailURL: thumbURL) { _, _ in }
                    }
                    
                    // Add to playlist if selected
                    if let playlistId = nextItem.playlistId {
                        self.api.addToPlaylist(videoId: videoId, playlistId: playlistId) { _, _ in }
                    }
                    
                    // Start status polling
                    self.pollVideoStatus(itemId: nextItem.id, videoId: videoId)
                } else {
                    self.updateItem(id: nextItem.id) { item in
                        item.status = .failed
                        item.errorMessage = error ?? "Upload failed"
                    }
                }
                
                self.isProcessing = false
                self.currentUploadId = nil
                
                // Process next item
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.processNextInQueue()
                }
            }
        )
    }
    
    // MARK: - Status Polling
    
    private func pollVideoStatus(itemId: UUID, videoId: String, attempts: Int = 0) {
        guard attempts < 30 else { return } // Max 30 attempts (5 minutes)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self else { return }
            
            self.api.checkVideoStatus(videoId: videoId) { status in
                guard let status = status else { return }
                
                self.updateItem(id: itemId) { item in
                    if status == .published {
                        item.status = .published
                        item.publishedAt = Date()
                    } else if status == .failed {
                        item.status = .failed
                    } else if status == .processing {
                        item.status = .processing
                        // Continue polling
                        self.pollVideoStatus(itemId: itemId, videoId: videoId, attempts: attempts + 1)
                    } else {
                        item.status = status
                    }
                }
            }
        }
    }
    
    // MARK: - Scheduler
    
    func startScheduler() {
        schedulerTimer?.invalidate()
        schedulerTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkScheduledUploads()
            self?.assignRecurringSlots()
        }
    }
    
    private func checkScheduledUploads() {
        let now = Date()
        for item in queue where item.status == .queued {
            if let scheduledDate = item.scheduledDate, scheduledDate <= now {
                updateItem(id: item.id) { item in
                    item.status = .ready
                }
            }
        }
        
        // Auto-start queue processing
        if !isProcessing && queue.contains(where: { $0.status == .ready }) {
            processNextInQueue()
        }
    }
    
    // MARK: - Recurring Schedule Assignment
    
    func assignRecurringSlots() {
        let settings = auth.getSettings()
        guard !settings.recurringRules.isEmpty else { return }
        
        let enabledRules = settings.recurringRules.filter { $0.isEnabled }
        guard !enabledRules.isEmpty else { return }
        
        // Find draft items that need scheduling
        let drafts = queue.filter { $0.status == .draft && $0.scheduledDate == nil }
        guard !drafts.isEmpty else { return }
        
        // Get next available slots
        let slots = getNextAvailableSlots(rules: enabledRules, count: drafts.count)
        
        for (index, draft) in drafts.enumerated() where index < slots.count {
            updateItem(id: draft.id) { item in
                item.scheduledDate = slots[index]
                item.status = .queued
            }
        }
    }
    
    func getNextAvailableSlots(rules: [RecurringScheduleRule], count: Int) -> [Date] {
        var slots: [Date] = []
        let calendar = Calendar.current
        var checkDate = Date()
        
        let takenDates = Set(queue.compactMap { item -> DateComponents? in
            guard let date = item.scheduledDate else { return nil }
            return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        })
        
        var daysChecked = 0
        while slots.count < count && daysChecked < 60 {
            let weekday = calendar.component(.weekday, from: checkDate)
            
            for rule in rules where rule.dayOfWeek == weekday {
                var components = calendar.dateComponents([.year, .month, .day], from: checkDate)
                components.hour = rule.hour
                components.minute = rule.minute
                
                if let slotDate = calendar.date(from: components), slotDate > Date() {
                    let slotComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: slotDate)
                    if !takenDates.contains(slotComponents) {
                        slots.append(slotDate)
                    }
                }
            }
            
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate)!
            daysChecked += 1
        }
        
        return slots.sorted()
    }
    
    // MARK: - Calendar Data
    
    func itemsForDate(_ date: Date) -> [YouTubeQueueItem] {
        let calendar = Calendar.current
        return queue.filter { item in
            guard let scheduled = item.scheduledDate else { return false }
            return calendar.isDate(scheduled, inSameDayAs: date)
        }
    }
    
    func itemsGroupedByDate() -> [(date: Date, items: [YouTubeQueueItem])] {
        let calendar = Calendar.current
        let scheduledItems = queue.filter { $0.scheduledDate != nil }
        
        var grouped: [Date: [YouTubeQueueItem]] = [:]
        for item in scheduledItems {
            guard let date = item.scheduledDate else { continue }
            let dayStart = calendar.startOfDay(for: date)
            grouped[dayStart, default: []].append(item)
        }
        
        return grouped.map { (date: $0.key, items: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    // MARK: - Quick Publish
    
    func quickPublish(
        projectState: ProjectState,
        videoURL: URL,
        thumbnailURL: URL?,
        metadata: ProjectMetadata,
        settings: YouTubePublishingSettings,
        visibility: YouTubeVisibility = .public,
        playlistId: String? = nil,
        scheduledDate: Date? = nil
    ) -> YouTubeQueueItem {
        // Generate title from default template
        let titleTemplate = settings.titleTemplates.first(where: { $0.isDefault }) ?? settings.titleTemplates.first ?? YouTubeTitleTemplate()
        let title = metadata.applyToTemplate(titleTemplate.format)
        
        // Generate description from default template
        let descTemplate = settings.descriptionTemplates.first(where: { $0.isDefault }) ?? settings.descriptionTemplates.first ?? YouTubeDescriptionTemplate()
        let description = metadata.applyToTemplate(descTemplate.format)
        
        // Generate tags
        let tagPreset = settings.tagPresets.first(where: { $0.isDefault }) ?? settings.tagPresets.first ?? YouTubeTagPreset()
        var tags = tagPreset.tags
        if !metadata.artist.isEmpty {
            tags.append(metadata.artist)
            tags.append("\(metadata.artist) lyrics")
        }
        if !metadata.song.isEmpty {
            tags.append(metadata.song)
            tags.append("\(metadata.song) lyrics")
        }
        
        var item = YouTubeQueueItem(
            projectId: projectState.id,
            videoFileURL: videoURL.path,
            thumbnailFileURL: thumbnailURL?.path
        )
        item.title = title
        item.description = description
        item.tags = tags
        item.category = settings.defaultCategory
        item.visibility = visibility
        item.playlistId = playlistId ?? settings.defaultPlaylistId
        item.scheduledDate = scheduledDate
        item.status = scheduledDate != nil ? .queued : .ready
        
        addToQueue(item)
        return item
    }
}
