import SwiftUI

struct YouTubeEditItemView: View {
    @ObservedObject var queueManager = YouTubeQueueManager.shared
    @ObservedObject var api = YouTubeAPIManager.shared
    let itemId: UUID
    var onClose: () -> Void
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var tags: String = ""
    @State private var category: YouTubeCategory = .music
    @State private var visibility: YouTubeVisibility = .public
    @State private var playlistId: String = ""
    @State private var scheduledDate: Date = Date()
    @State private var isScheduled: Bool = false
    
    @State private var isSaving = false
    @State private var saveError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Video")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { onClose() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            if isSaving {
                VStack {
                    Spacer()
                    ProgressView("Saving changes to YouTube...")
                        .tint(.white)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    Section(header: Text("Metadata").foregroundColor(.gray)) {
                        TextField("Title", text: $title)
                        TextEditor(text: $description)
                            .frame(height: 80)
                        TextField("Tags (comma separated)", text: $tags)
                        
                        Picker("Category", selection: $category) {
                            ForEach(YouTubeCategory.allCases, id: \.self) { cat in
                                Text(cat.displayName).tag(cat)
                            }
                        }
                        
                        Picker("Visibility", selection: $visibility) {
                            ForEach(YouTubeVisibility.allCases, id: \.self) { vis in
                                Text(vis.displayName).tag(vis)
                            }
                        }
                        
                        Picker("Playlist", selection: $playlistId) {
                            Text("None").tag("")
                            ForEach(api.playlists) { playlist in
                                Text(playlist.title).tag(playlist.id)
                            }
                        }
                    }
                    
                    Section(header: Text("Scheduling").foregroundColor(.gray)) {
                        Toggle("Schedule Publishing", isOn: $isScheduled)
                        if isScheduled {
                            DatePicker("Date & Time", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                }
                .padding(.horizontal, 20)
                .formStyle(.grouped)
            }
            
            if let error = saveError {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }
            
            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    onClose()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                
                Button("Save Changes") {
                    saveChanges()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(isSaving)
            }
            .padding(20)
        }
        .frame(width: 450, height: 550)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
        .onAppear {
            loadItem()
        }
    }
    
    private func loadItem() {
        guard let item = queueManager.queue.first(where: { $0.id == itemId }) else { return }
        title = item.title
        description = item.description
        tags = item.tags.joined(separator: ", ")
        category = item.category
        visibility = item.visibility
        playlistId = item.playlistId ?? ""
        if let date = item.scheduledDate {
            isScheduled = true
            scheduledDate = date
        } else {
            isScheduled = false
        }
    }
    
    private func saveChanges() {
        guard let item = queueManager.queue.first(where: { $0.id == itemId }) else { return }
        
        let tagsArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let finalPlaylistId = playlistId.isEmpty ? nil : playlistId
        let finalScheduledDate = isScheduled ? scheduledDate : nil
        
        if let videoId = item.youtubeVideoId, item.status == .published || item.status == .scheduled || item.status == .processing {
            // Already uploaded, need to sync with YouTube
            isSaving = true
            api.updateVideoMetadata(
                videoId: videoId,
                title: title,
                description: description,
                tags: tagsArray,
                category: category,
                visibility: visibility,
                publishAt: finalScheduledDate
            ) { success, error in
                DispatchQueue.main.async {
                    if success {
                        // Metadata updated successfully. 
                        if let playlist = finalPlaylistId, playlist != item.playlistId {
                            self.api.addToPlaylist(videoId: videoId, playlistId: playlist) { _, _ in }
                        }
                        updateLocalItemAndClose(tagsArray: tagsArray, finalPlaylistId: finalPlaylistId, finalScheduledDate: finalScheduledDate)
                    } else {
                        self.saveError = error ?? "Failed to sync with YouTube"
                        self.isSaving = false
                    }
                }
            }
        } else {
            // Not uploaded yet, just update locally
            updateLocalItemAndClose(tagsArray: tagsArray, finalPlaylistId: finalPlaylistId, finalScheduledDate: finalScheduledDate)
        }
    }
    
    private func updateLocalItemAndClose(tagsArray: [String], finalPlaylistId: String?, finalScheduledDate: Date?) {
        queueManager.updateItem(id: itemId) { updatedItem in
            updatedItem.title = title
            updatedItem.description = description
            updatedItem.tags = tagsArray
            updatedItem.category = category
            updatedItem.visibility = visibility
            updatedItem.playlistId = finalPlaylistId
            updatedItem.scheduledDate = finalScheduledDate
            
            if updatedItem.status == .draft && finalScheduledDate != nil {
                updatedItem.status = .queued
            }
            if updatedItem.status == .queued && finalScheduledDate == nil {
                updatedItem.status = .draft // or ready depending on setup
            }
        }
        onClose()
    }
}
