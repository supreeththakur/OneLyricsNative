import SwiftUI

struct DayGroup: Identifiable {
    var id: String { dateStr }
    let dateStr: String
    let date: Date
    let projects: [ProjectState]
}

struct MediaExporterView: View {
    @ObservedObject var manager = ExportManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showYouTubePublish = false
    @State private var selectedVideoURL: URL? = nil
    
    @StateObject private var projectManager = ProjectManager()
    @State private var projectToExport: ProjectState? = nil
    @State private var projectToThumbnail: ProjectState? = nil
    
    @State private var expandedNotExportedDays: Set<String> = []
    @State private var expandedExportedDays: Set<String> = []
    @State private var didInitializeExpansions = false
    
    private func groupProjectsByDay(_ projects: [ProjectState]) -> [DayGroup] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        
        let grouped = Dictionary(grouping: projects) { (proj: ProjectState) -> Date in
            Calendar.current.startOfDay(for: proj.createdAt)
        }
        
        return grouped.map { (date, projs) in
            DayGroup(dateStr: formatter.string(from: date), date: date, projects: projs.sorted { $0.createdAt > $1.createdAt })
        }.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Media Exporter")
                    .font(.headline)
                Spacer()
                Button(action: {
                    if ProcessInfo.processInfo.processName.lowercased().contains("exporter") || ProcessInfo.processInfo.arguments.contains("--exporter") {
                        NSApplication.shared.terminate(nil)
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            List {
                let activeJobs = manager.jobs.filter { $0.status == .exporting || $0.status == .paused }
                let queuedJobs = manager.jobs.filter { $0.status == .queued }.sorted { $0.priority > $1.priority }
                let completedJobs = manager.jobs.filter { $0.status == .completed }.sorted { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) }
                let failedJobs = manager.jobs.filter { $0.status == .failed || $0.status == .cancelled }
                
                let completedNames = Set(completedJobs.map { $0.projectName })
                let exportedProjects = projectManager.projects.filter { completedNames.contains($0.title) }
                let notExportedProjects = projectManager.projects.filter { !completedNames.contains($0.title) }
                
                if manager.jobs.isEmpty && projectManager.projects.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No items in queue or saved projects")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
                    .listRowBackground(Color.clear)
                } else {
                    if !activeJobs.isEmpty {
                        Section(header: Text("Currently Exporting").font(.subheadline).foregroundColor(.gray)) {
                            ForEach(activeJobs) { job in
                                ActiveExportRow(job: job)
                            }
                        }
                    }
                    
                    if !queuedJobs.isEmpty {
                        Section(header: Text("Up Next").font(.subheadline).foregroundColor(.gray)) {
                            ForEach(queuedJobs) { job in
                                QueuedExportRow(job: job)
                            }
                        }
                    }
                    
                    if !completedJobs.isEmpty {
                        Section(header: Text("Completed Jobs").font(.subheadline).foregroundColor(.gray)) {
                            ForEach(completedJobs) { job in
                                CompletedExportRow(job: job) {
                                    self.selectedVideoURL = job.outputURL
                                    self.showYouTubePublish = true
                                }
                            }
                            Button("Clear Completed") {
                                manager.clearCompleted()
                            }
                            .buttonStyle(.link)
                            .padding(.top, 4)
                        }
                    }
                    
                    let notExportedGroups = groupProjectsByDay(notExportedProjects)
                    let exportedGroups = groupProjectsByDay(exportedProjects)
                    
                    if !notExportedGroups.isEmpty {
                        Section(header: Text("Projects (Not Exported)").font(.subheadline).foregroundColor(.gray)) {
                            ForEach(notExportedGroups) { group in
                                DisclosureGroup(isExpanded: Binding(
                                    get: { expandedNotExportedDays.contains(group.id) },
                                    set: { isExpanding in
                                        if isExpanding { expandedNotExportedDays.insert(group.id) }
                                        else { expandedNotExportedDays.remove(group.id) }
                                    }
                                )) {
                                    ForEach(group.projects, id: \.id) { project in
                                        ProjectExportRow(project: project, onThumbnail: {
                                            self.projectToThumbnail = project
                                        })
                                    }
                                } label: {
                                    Text(group.dateStr).font(.subheadline).bold()
                                }
                            }
                        }
                    }
                    
                    if !exportedGroups.isEmpty {
                        Section(header: Text("Projects (Exported)").font(.subheadline).foregroundColor(.gray)) {
                            ForEach(exportedGroups) { group in
                                DisclosureGroup(isExpanded: Binding(
                                    get: { expandedExportedDays.contains(group.id) },
                                    set: { isExpanding in
                                        if isExpanding { expandedExportedDays.insert(group.id) }
                                        else { expandedExportedDays.remove(group.id) }
                                    }
                                )) {
                                    ForEach(group.projects, id: \.id) { project in
                                        ProjectExportRow(project: project, onThumbnail: {
                                            self.projectToThumbnail = project
                                        })
                                    }
                                } label: {
                                    Text(group.dateStr).font(.subheadline).bold()
                                }
                            }
                        }
                    }
                    
                    if !failedJobs.isEmpty {
                        Section(header: Text("Failed / Cancelled").font(.subheadline).foregroundColor(.gray)) {
                            ForEach(failedJobs) { job in
                                FailedExportRow(job: job)
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .onAppear {
                if !didInitializeExpansions {
                    let notExportedGroups = groupProjectsByDay(projectManager.projects.filter { !Set(manager.jobs.filter { $0.status == .completed }.map { $0.projectName }).contains($0.title) })
                    let exportedGroups = groupProjectsByDay(projectManager.projects.filter { Set(manager.jobs.filter { $0.status == .completed }.map { $0.projectName }).contains($0.title) })
                    
                    if let first = notExportedGroups.first { expandedNotExportedDays.insert(first.id) }
                    if let first = exportedGroups.first { expandedExportedDays.insert(first.id) }
                    
                    didInitializeExpansions = true
                }
            }
            
            // YouTube Publish Modal Overlay
            if showYouTubePublish {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { showYouTubePublish = false }
                    .zIndex(100)
                
                YouTubePublishView(isPresented: $showYouTubePublish, videoFileURL: selectedVideoURL, initialSchedule: false)
                    .zIndex(101)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            
            // Export Settings Modal Overlay
            // Thumbnail Settings Modal Overlay
            if let project = projectToThumbnail {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { projectToThumbnail = nil }
                    .zIndex(104)
                
                ThumbnailModalWrapper(project: project, isPresented: Binding(
                    get: { projectToThumbnail != nil },
                    set: { if !$0 { projectToThumbnail = nil } }
                ))
                .zIndex(105)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .frame(width: 450, height: 600)
    }
}

struct ActiveExportRow: View {
    var job: ExportJob
    @ObservedObject var manager = ExportManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.projectName)
                        .font(.headline)
                    Text("\(job.resolution) • \(job.format) • \(job.bitrate) Bitrate")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Button(action: {
                    manager.cancelJob(id: job.id)
                }) {
                    Text("Cancel")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: geo.size.width * CGFloat(job.progress), height: 6)
                            .cornerRadius(3)
                    }
                }
                .frame(height: 6)
                
                Text("\(Int(job.progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}

struct QueuedExportRow: View {
    var job: ExportJob
    @ObservedObject var manager = ExportManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(job.projectName)
                    .font(.subheadline)
                Text("\(job.resolution) • \(job.format) • Priority: \(job.priority == .high ? "High" : job.priority == .low ? "Low" : "Normal")")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Spacer()
            Button(action: {
                manager.cancelJob(id: job.id)
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct CompletedExportRow: View {
    var job: ExportJob
    var onPublish: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.projectName)
                    .font(.subheadline)
                Text(job.outputURL.lastPathComponent)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Spacer()
            
            Button(action: {
                onPublish()
            }) {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            
            Button(action: {
                NSWorkspace.shared.activateFileViewerSelecting([job.outputURL])
            }) {
                Image(systemName: "folder")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct FailedExportRow: View {
    var job: ExportJob
    @ObservedObject var manager = ExportManager.shared
    
    var body: some View {
        HStack {
            Image(systemName: job.status == .cancelled ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(job.status == .cancelled ? .gray : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.projectName)
                    .font(.subheadline)
                if let err = job.error {
                    Text(err)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button(action: {
                manager.retryJob(id: job.id)
            }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                manager.removeJob(id: job.id)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct ProjectExportRow: View {
    var project: ProjectState
    var onThumbnail: () -> Void
    
    @AppStorage("export_selectedFormat") private var selectedFormat = "MP4"
    @AppStorage("export_selectedResolution") private var selectedResolution = "1080p"
    @AppStorage("export_selectedBitrate") private var selectedBitrate = "High"
    @AppStorage("export_outputPath") private var outputPath = ""
    @AppStorage("export_uploadToYouTube") private var uploadToYouTube = false
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
            Text(project.title)
                .font(.subheadline)
            Spacer()
            
            Button(action: {
                onThumbnail()
            }) {
                Image(systemName: "photo.artframe")
                    .foregroundColor(.orange)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            
            Button("Add Queue") {
                queueProjectDirectly()
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.green)
            .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }
    
    private func queueProjectDirectly() {
        let ext = selectedFormat == "MOV" ? "mov" : "mp4"
        let sanitizedName = project.title.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
        let projectName = sanitizedName.isEmpty ? "OneLyrics_Export" : sanitizedName
        let finalPath = outputPath.isEmpty ? NSHomeDirectory() + "/Desktop/\(projectName).\(ext)" : outputPath
        
        var url = URL(fileURLWithPath: finalPath)
        if url.pathExtension.lowercased() != ext {
            url = url.deletingPathExtension().appendingPathExtension(ext)
        }
        
        var effectiveDuration: Double = 60000
        if project.durationMs > 0 && !project.durationMs.isNaN { 
            effectiveDuration = project.durationMs
        } else if let last = project.lyrics.max(by: { $0.endMs < $1.endMs }) {
            effectiveDuration = max(last.endMs + 5000, 60000)
        }
        
        ExportManager.shared.addJob(
            projectName: projectName,
            state: project,
            durationMs: effectiveDuration,
            format: selectedFormat,
            resolution: selectedResolution,
            bitrate: selectedBitrate,
            outputURL: url,
            publishToYouTube: uploadToYouTube,
            priority: .normal
        )
    }
}



struct ThumbnailModalWrapper: View {
    var project: ProjectState
    @Binding var isPresented: Bool
    
    @StateObject private var dummyStore = ProjectStore()
    
    var body: some View {
        ThumbnailMakerModal(isPresented: $isPresented)
            .environmentObject(dummyStore)
            .onAppear {
                dummyStore.state = project
                dummyStore.isShowingThumbnailMaker = true // Because ThumbnailMakerModal might rely on this internally, though we bound it to $isPresented.
            }
    }
}
