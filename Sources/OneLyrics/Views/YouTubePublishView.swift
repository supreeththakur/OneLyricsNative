import SwiftUI
import AppKit

// MARK: - YouTube Publish View

struct YouTubePublishView: View {
    @EnvironmentObject var store: ProjectStore
    @Binding var isPresented: Bool
    
    @ObservedObject var auth = YouTubeAuthManager.shared
    @ObservedObject var api = YouTubeAPIManager.shared
    @ObservedObject var queueManager = YouTubeQueueManager.shared
    
    @State private var currentTab: PublishTab = .publish
    
    // Metadata fields
    @State private var videoTitle: String = ""
    @State private var videoDescription: String = ""
    @State private var videoTags: String = ""
    @State private var selectedCategory: YouTubeCategory = .music
    @State private var selectedVisibility: YouTubeVisibility = .public
    @State private var selectedPlaylistId: String? = nil
    @State private var thumbnailPath: String? = nil
    @State private var thumbnailImage: NSImage? = nil
    
    // Scheduling
    @State private var isScheduled: Bool = false
    @State private var scheduledDate: Date = Date().addingTimeInterval(86400)
    @State private var selectedTimezone: String = TimeZone.current.identifier
    
    // Video file
    var videoFileURL: URL?
    var initialSchedule: Bool = false
    
    // State
    @State private var isUploading: Bool = false
    @State private var uploadProgress: Double = 0
    @State private var uploadSpeed: String = ""
    @State private var remainingTime: String = ""
    @State private var uploadError: String?
    @State private var uploadSuccess: Bool = false
    @State private var uploadedVideoId: String?
    @State private var editingItemId: UUID? = nil
    
    enum PublishTab: String, CaseIterable {
        case publish = "Publish"
        case queue = "Queue"
        case calendar = "Calendar"
        case settings = "Settings"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Tab Bar
            tabBar
            
            // Content
            ScrollView(.vertical, showsIndicators: true) {
                switch currentTab {
                case .publish:
                    publishContent
                case .queue:
                    queueContent
                case .calendar:
                    calendarContent
                case .settings:
                    settingsContent
                }
            }
            
            if let editId = editingItemId {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { editingItemId = nil }
                    .zIndex(200)
                YouTubeEditItemView(itemId: editId, onClose: { editingItemId = nil })
                    .zIndex(201)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .frame(width: 620, height: 680)
        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 15)
        .onAppear {
            isScheduled = initialSchedule
            setupInitialMetadata()
            if auth.isAuthenticated {
                api.fetchPlaylists()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                Text("YouTube Publishing")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
            }
            Spacer()
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.08, green: 0.08, blue: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(PublishTab.allCases, id: \.self) { tab in
                Button(action: { currentTab = tab }) {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: currentTab == tab ? .bold : .medium))
                            .foregroundColor(currentTab == tab ? .red : .gray)
                        
                        Rectangle()
                            .fill(currentTab == tab ? Color.red : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white.opacity(0.03))
    }
    
    // MARK: - Publish Content
    
    private var publishContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !auth.isAuthenticated {
                connectChannelPrompt
            } else if isUploading {
                uploadProgressView
            } else if uploadSuccess {
                uploadSuccessView
            } else {
                channelInfoBar
                metadataEditor
                actionButtons
            }
        }
        .padding(20)
    }
    
    // MARK: - Connect Channel Prompt
    
    private var connectChannelPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red.opacity(0.6))
            
            Text("Connect Your YouTube Channel")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            
            Text("Sign in with your Google account to upload videos directly from OneLyrics.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Button(action: { auth.authenticate() }) {
                HStack {
                    if auth.isAuthenticating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Image(systemName: "person.badge.key.fill")
                    Text(auth.isAuthenticating ? "Connecting..." : "Connect with Google")
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(auth.isAuthenticating)
            
            if let error = auth.authError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Channel Info Bar
    
    private var channelInfoBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(auth.channel?.channelName ?? "YouTube Channel")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Connected")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            if let subs = auth.channel?.subscriberCount {
                Text("\(subs) subs")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
    }
    
    // MARK: - Metadata Editor
    
    private var metadataEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Title").foregroundColor(.gray).font(.caption.weight(.semibold))
                    Spacer()
                    Menu {
                        let settings = auth.getSettings()
                        ForEach(settings.titleTemplates) { template in
                            Button(template.name) {
                                let meta = ProjectMetadata.fromProjectState(store.state)
                                videoTitle = meta.applyToTemplate(template.format)
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "wand.and.stars")
                            Text("Auto")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.purple)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                }
                TextField("Video title...", text: $videoTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Description").foregroundColor(.gray).font(.caption.weight(.semibold))
                    Spacer()
                    Menu {
                        let settings = auth.getSettings()
                        ForEach(settings.descriptionTemplates) { template in
                            Button(template.name) {
                                let meta = ProjectMetadata.fromProjectState(store.state)
                                videoDescription = meta.applyToTemplate(template.format)
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "wand.and.stars")
                            Text("Auto")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.purple)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                }
                TextEditor(text: $videoDescription)
                    .font(.system(size: 12))
                    .frame(height: 80)
                    .padding(6)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            
            // Tags
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tags").foregroundColor(.gray).font(.caption.weight(.semibold))
                    Spacer()
                    Button(action: { autoGenerateTags() }) {
                        HStack(spacing: 2) {
                            Image(systemName: "wand.and.stars")
                            Text("Auto")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                }
                TextField("Separate tags with commas...", text: $videoTags)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            
            // Category & Visibility Row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category").foregroundColor(.gray).font(.caption.weight(.semibold))
                    Picker("", selection: $selectedCategory) {
                        ForEach(YouTubeCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Visibility").foregroundColor(.gray).font(.caption.weight(.semibold))
                    Picker("", selection: $selectedVisibility) {
                        ForEach(YouTubeVisibility.allCases, id: \.self) { vis in
                            HStack {
                                Image(systemName: vis.icon)
                                Text(vis.displayName)
                            }.tag(vis)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
            }
            
            // Playlist
            VStack(alignment: .leading, spacing: 4) {
                Text("Playlist").foregroundColor(.gray).font(.caption.weight(.semibold))
                Picker("", selection: Binding(
                    get: { selectedPlaylistId ?? "" },
                    set: { selectedPlaylistId = $0.isEmpty ? nil : $0 }
                )) {
                    Text("None").tag("")
                    ForEach(api.playlists) { playlist in
                        Text("\(playlist.title) (\(playlist.itemCount))").tag(playlist.id)
                    }
                }
                .labelsHidden()
            }
            
            // Thumbnail Preview
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Thumbnail").foregroundColor(.gray).font(.caption.weight(.semibold))
                    Spacer()
                    Button("Change") { chooseThumbnail() }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                        .buttonStyle(.plain)
                }
                
                if let img = thumbnailImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(height: 90)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 90)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                Text("Auto-generated from project")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        )
                }
            }
            
            // Scheduling Toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $isScheduled) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.blue)
                        Text("Schedule Publishing")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .tint(.blue)
                
                if isScheduled {
                    HStack(spacing: 12) {
                        DatePicker("", selection: $scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        
                        Picker("", selection: $selectedTimezone) {
                            Text("IST").tag("Asia/Kolkata")
                            Text("EST").tag("America/New_York")
                            Text("PST").tag("America/Los_Angeles")
                            Text("UTC").tag("UTC")
                            Text("GMT").tag("Europe/London")
                        }
                        .labelsHidden()
                        .frame(width: 80)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Cancel") { isPresented = false }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .foregroundColor(.white)
                .cornerRadius(8)
            
            Spacer()
            
            Button(action: { addToQueueAction() }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add to Queue")
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Button(action: { startUpload() }) {
                HStack {
                    Image(systemName: isScheduled ? "calendar.badge.clock" : "arrow.up.circle.fill")
                    Text(isScheduled ? "Schedule" : "Publish Now")
                }
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Upload Progress View
    
    private var uploadProgressView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: uploadProgress)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: uploadProgress)
                
                VStack(spacing: 2) {
                    Text("\(Int(uploadProgress * 100))%")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Uploading")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
            
            Text(videoTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text(uploadSpeed)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text("Speed")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 2) {
                    Text(remainingTime)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                    Text("Remaining")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Upload Success View
    
    private var uploadSuccessView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text(isScheduled ? "Scheduled Successfully!" : "Published Successfully!")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            
            if let videoId = uploadedVideoId {
                Text("https://youtube.com/watch?v=\(videoId)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                
                Button("Open on YouTube") {
                    if let url = URL(string: "https://youtube.com/watch?v=\(videoId)") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Button("Done") { isPresented = false }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .foregroundColor(.white)
                .cornerRadius(8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Queue Content
    
    private var queueContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if queueManager.queue.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No Videos in Queue")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Add videos to your publishing queue from the Publish tab.")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                HStack {
                    Text("Upload Queue")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if !queueManager.isProcessing {
                        Button(action: { queueManager.processNextInQueue() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                Text("Start Queue")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                ForEach(queueManager.queue) { item in
                    queueItemRow(item)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)
            }
        }
    }
    
    private func queueItemRow(_ item: YouTubeQueueItem) -> some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.06))
                .frame(width: 80, height: 45)
                .overlay(
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(.gray.opacity(0.5))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title.isEmpty ? "Untitled" : item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    // Status badge
                    statusBadge(item.status)
                    
                    if let date = item.scheduledDate {
                        Text(formatScheduleDate(date))
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                
                if item.status == .uploading {
                    ProgressView(value: item.uploadProgress)
                        .progressViewStyle(.linear)
                        .tint(.red)
                        .frame(height: 3)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 4) {
                if item.status == .draft || item.status == .ready || item.status == .queued {
                    if let index = queueManager.queue.firstIndex(where: { $0.id == item.id }) {
                        if index > 0 {
                            Button(action: { queueManager.reorderQueue(from: IndexSet(integer: index), to: index - 1) }) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                            .help("Move Up")
                        }
                        
                        if index < queueManager.queue.count - 1 {
                            Button(action: { queueManager.reorderQueue(from: IndexSet(integer: index), to: index + 2) }) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                            .help("Move Down")
                        }
                    }
                }
                if item.status == .uploading || item.status == .processing {
                    Button(action: { queueManager.cancelItem(id: item.id) }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel")
                }
                
                if item.status == .failed {
                    Button(action: { queueManager.retryItem(id: item.id) }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .help("Retry")
                }
                
                Button(action: { editingItemId = item.id }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Edit & Reschedule")
                
                if item.status != .uploading && item.status != .processing {
                    Button(action: { queueManager.removeFromQueue(id: item.id) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Remove")
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
    
    private func statusBadge(_ status: YouTubeUploadStatus) -> some View {
        HStack(spacing: 3) {
            Image(systemName: status.icon)
                .font(.system(size: 8))
            Text(status.rawValue)
                .font(.system(size: 9, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor(status).opacity(0.2))
        .foregroundColor(statusColor(status))
        .cornerRadius(4)
    }
    
    private func statusColor(_ status: YouTubeUploadStatus) -> Color {
        switch status {
        case .draft: return .gray
        case .ready: return .teal
        case .queued: return .yellow
        case .uploading: return .purple
        case .processing: return .orange
        case .scheduled: return .blue
        case .published: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
    
    // MARK: - Calendar Content
    
    private var calendarContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Publishing Calendar")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            let grouped = queueManager.itemsGroupedByDate()
            
            if grouped.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No Scheduled Uploads")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                ForEach(grouped, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(formatCalendarDate(group.date))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(formatDayName(group.date))
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        
                        ForEach(group.items) { item in
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(statusColor(item.status))
                                    .frame(width: 3, height: 36)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title.isEmpty ? "Untitled" : item.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    if let date = item.scheduledDate {
                                        Text(formatTime(date))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: { editingItemId = item.id }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 4)
                                
                                statusBadge(item.status)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - Settings Content
    
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Channel Section
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Channel Connection")
                
                if auth.isAuthenticated {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.red)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.channel?.channelName ?? "Connected")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("Connected")
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Disconnect") { auth.disconnect() }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                            .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                } else {
                    Button(action: { auth.authenticate() }) {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                            Text("Connect YouTube Channel")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Recurring Schedule
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Recurring Publishing Schedule")
                
                let settings = auth.getSettings()
                
                ForEach(settings.recurringRules) { rule in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { rule.isEnabled },
                            set: { newValue in
                                var updated = settings
                                if let idx = updated.recurringRules.firstIndex(where: { $0.id == rule.id }) {
                                    updated.recurringRules[idx].isEnabled = newValue
                                    auth.updateSettings(updated)
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(.red)
                        
                        Text(rule.dayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 90, alignment: .leading)
                        
                        Text(rule.timeString)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Button(action: {
                            var updated = settings
                            updated.recurringRules.removeAll { $0.id == rule.id }
                            auth.updateSettings(updated)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(.red.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(6)
                }
                
                Button(action: { addRecurringRule() }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Day")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            // Default Settings
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Defaults")
                
                HStack {
                    Text("Default Visibility")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { auth.getSettings().defaultVisibility },
                        set: { newValue in
                            var s = auth.getSettings()
                            s.defaultVisibility = newValue
                            auth.updateSettings(s)
                        }
                    )) {
                        ForEach(YouTubeVisibility.allCases, id: \.self) { vis in
                            Text(vis.displayName).tag(vis)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
                
                HStack {
                    Text("Default Category")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { auth.getSettings().defaultCategory },
                        set: { newValue in
                            var s = auth.getSettings()
                            s.defaultCategory = newValue
                            auth.updateSettings(s)
                        }
                    )) {
                        ForEach(YouTubeCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
            }
        }
        .padding(20)
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.gray)
            .tracking(1.2)
    }
    
    private func setupInitialMetadata() {
        let meta = ProjectMetadata.fromProjectState(store.state)
        let settings = auth.getSettings()
        
        // Auto-generate title
        let titleTemplate = settings.titleTemplates.first(where: { $0.isDefault }) ?? settings.titleTemplates.first ?? YouTubeTitleTemplate()
        videoTitle = meta.applyToTemplate(titleTemplate.format)
        
        // Auto-generate description
        let descTemplate = settings.descriptionTemplates.first(where: { $0.isDefault }) ?? settings.descriptionTemplates.first ?? YouTubeDescriptionTemplate()
        videoDescription = meta.applyToTemplate(descTemplate.format)
        
        // Auto-generate tags
        autoGenerateTags()
        
        selectedCategory = settings.defaultCategory
        selectedVisibility = settings.defaultVisibility
        selectedPlaylistId = settings.defaultPlaylistId
        
        // Load thumbnail from project
        loadProjectThumbnail()
    }
    
    private func autoGenerateTags() {
        let meta = ProjectMetadata.fromProjectState(store.state)
        var tags: [String] = []
        if !meta.artist.isEmpty {
            tags.append(meta.artist)
            tags.append("\(meta.artist) lyrics")
        }
        if !meta.song.isEmpty {
            tags.append(meta.song)
            tags.append("\(meta.song) lyrics")
        }
        tags.append("lyrics")
        tags.append("lyric video")
        tags.append("OneLyrics")
        videoTags = tags.joined(separator: ", ")
    }
    
    private func loadProjectThumbnail() {
        Task {
            if let img = await ProjectThumbnailExporter.generateThumbnail(
                state: store.state,
                textSize: 200,
                glow: store.state.typography.glow,
                shadowOffset: .zero
            ) {
                DispatchQueue.main.async {
                    self.thumbnailImage = img
                }
            }
        }
    }
    
    private func chooseThumbnail() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            thumbnailPath = url.path
            thumbnailImage = NSImage(contentsOf: url)
        }
    }
    
    private func addToQueueAction() {
        let tags = videoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        var item = YouTubeQueueItem(
            projectId: store.state.id,
            videoFileURL: videoFileURL?.path ?? ""
        )
        item.title = videoTitle
        item.description = videoDescription
        item.tags = tags
        item.category = selectedCategory
        item.visibility = selectedVisibility
        item.playlistId = selectedPlaylistId
        item.scheduledDate = isScheduled ? scheduledDate : nil
        
        if isScheduled {
            item.status = .queued
        } else {
            let settings = auth.getSettings()
            let hasRecurring = settings.recurringRules.contains(where: { $0.isEnabled })
            item.status = hasRecurring ? .draft : .ready
        }
        
        // Save thumbnail
        if let img = thumbnailImage {
            let thumbURL = saveThumbnailToFile(img)
            item.thumbnailFileURL = thumbURL?.path
        }
        
        queueManager.addToQueue(item)
        currentTab = .queue
    }
    
    private func startUpload() {
        let tags = videoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        var item = YouTubeQueueItem(
            projectId: store.state.id,
            videoFileURL: videoFileURL?.path ?? ""
        )
        item.title = videoTitle
        item.description = videoDescription
        item.tags = tags
        item.category = selectedCategory
        item.visibility = selectedVisibility
        item.playlistId = selectedPlaylistId
        item.scheduledDate = isScheduled ? scheduledDate : nil
        item.status = .ready
        
        // Save thumbnail
        if let img = thumbnailImage {
            let thumbURL = saveThumbnailToFile(img)
            item.thumbnailFileURL = thumbURL?.path
        }
        
        queueManager.addToQueue(item)
        
        isUploading = true
        
        api.uploadVideo(
            item: item,
            onProgress: { progress, speed, remaining in
                self.uploadProgress = progress
                self.uploadSpeed = speed
                self.remainingTime = remaining
                
                self.queueManager.updateItem(id: item.id) { qItem in
                    qItem.uploadProgress = progress
                    qItem.uploadSpeed = speed
                    qItem.remainingTime = remaining
                    qItem.status = .uploading
                }
            },
            onComplete: { videoId, error in
                self.isUploading = false
                
                if let videoId = videoId {
                    self.uploadedVideoId = videoId
                    self.uploadSuccess = true
                    
                    self.queueManager.updateItem(id: item.id) { qItem in
                        qItem.youtubeVideoId = videoId
                        qItem.youtubeVideoURL = "https://www.youtube.com/watch?v=\(videoId)"
                        qItem.status = self.isScheduled ? .scheduled : .published
                        qItem.publishedAt = Date()
                    }
                    
                    // Set thumbnail
                    if let thumbPath = item.thumbnailFileURL {
                        self.api.setThumbnail(videoId: videoId, thumbnailURL: URL(fileURLWithPath: thumbPath)) { _, _ in }
                    }
                    
                    // Add to playlist
                    if let playlistId = item.playlistId {
                        self.api.addToPlaylist(videoId: videoId, playlistId: playlistId) { _, _ in }
                    }
                } else {
                    self.uploadError = error
                    self.queueManager.updateItem(id: item.id) { qItem in
                        qItem.status = .failed
                        qItem.errorMessage = error
                    }
                }
            }
        )
    }
    
    private func saveThumbnailToFile(_ image: NSImage) -> URL? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else { return nil }
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("OneLyrics/YouTube/Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        
        let thumbURL = folder.appendingPathComponent("\(UUID().uuidString).jpg")
        try? data.write(to: thumbURL)
        return thumbURL
    }
    
    private func addRecurringRule() {
        var settings = auth.getSettings()
        let existingDays = Set(settings.recurringRules.map { $0.dayOfWeek })
        let allDays = [2, 4, 6, 1] // Mon, Wed, Fri, Sun
        let nextDay = allDays.first { !existingDays.contains($0) } ?? 2
        
        settings.recurringRules.append(RecurringScheduleRule(dayOfWeek: nextDay, hour: 19, minute: 0))
        auth.updateSettings(settings)
    }
    
    // MARK: - Date Formatters
    
    private func formatScheduleDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatCalendarDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatDayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
