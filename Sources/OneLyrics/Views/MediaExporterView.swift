import SwiftUI

struct DayGroup: Identifiable {
    let id: String
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
    
    @State private var showSettings = false
    
    private func groupProjectsByDay(_ projects: [ProjectState], prefix: String) -> [DayGroup] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        
        let grouped = Dictionary(grouping: projects) { (proj: ProjectState) -> Date in
            Calendar.current.startOfDay(for: proj.createdAt)
        }
        
        return grouped.map { (date, projs) in
            let dateStr = formatter.string(from: date)
            return DayGroup(id: "\(prefix)_\(dateStr)", dateStr: dateStr, date: date, projects: projs.sorted { $0.createdAt > $1.createdAt })
        }.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Media Exporter")
                    .font(.title3)
                Spacer()
                
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                
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
                        HStack {
                            Spacer()
                            Text("Currently Exporting").font(.title3).bold().foregroundColor(.gray).frame(width: 820, alignment: .leading)
                            Spacer()
                        }
                        .padding(.top, 16).padding(.bottom, 4)
                        
                        ForEach(activeJobs) { job in
                            ActiveExportRow(job: job)
                        }
                    }
                    
                    if !queuedJobs.isEmpty {
                        HStack {
                            Spacer()
                            Text("Up Next").font(.title3).bold().foregroundColor(.gray).frame(width: 820, alignment: .leading)
                            Spacer()
                        }
                        .padding(.top, 16).padding(.bottom, 4)
                        
                        ForEach(queuedJobs) { job in
                            QueuedExportRow(job: job)
                        }
                    }
                    
                    if !completedJobs.isEmpty {
                        HStack {
                            Spacer()
                            Text("Completed Jobs").font(.title3).bold().foregroundColor(.gray).frame(width: 820, alignment: .leading)
                            Spacer()
                        }
                        .padding(.top, 16).padding(.bottom, 4)
                        
                        ForEach(completedJobs) { job in
                            CompletedExportRow(job: job) {
                                self.selectedVideoURL = job.outputURL
                                self.showYouTubePublish = true
                            }
                        }
                        
                        HStack {
                            Spacer()
                            Button("Clear Completed") {
                                manager.clearCompleted()
                            }
                            .buttonStyle(.link)
                            .frame(width: 820, alignment: .leading)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                    
                    let notExportedGroups = groupProjectsByDay(notExportedProjects, prefix: "not_exported")
                    let exportedGroups = groupProjectsByDay(exportedProjects, prefix: "exported")
                    
                    if !notExportedGroups.isEmpty {
                        HStack {
                            Spacer()
                            Text("Projects (Not Exported)").font(.title3).bold().foregroundColor(.gray).frame(width: 820, alignment: .leading)
                            Spacer()
                        }
                        .padding(.top, 16).padding(.bottom, 4)
                        
                        ForEach(notExportedGroups) { group in
                            HStack {
                                Spacer()
                                VStack(spacing: 0) {
                                Button(action: {
                                    if expandedNotExportedDays.contains(group.id) {
                                        expandedNotExportedDays.remove(group.id)
                                    } else {
                                        expandedNotExportedDays.insert(group.id)
                                    }
                                }) {
                                    HStack {
                                        Spacer()
                                        HStack {
                                            Image(systemName: expandedNotExportedDays.contains(group.id) ? "chevron.down" : "chevron.right")
                                                .foregroundColor(.gray)
                                                .frame(width: 20)
                                            Text(group.dateStr).font(.title2).bold().foregroundColor(.white)
                                        }
                                        .padding(.vertical, 14).padding(.horizontal, 20)
                                        .frame(width: 820, alignment: .leading)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.4), lineWidth: 1))
                                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 8)
                                
                                if expandedNotExportedDays.contains(group.id) {
                                    VStack(spacing: 0) {
                                        ForEach(group.projects, id: \.id) { project in
                                            ProjectExportRow(project: project, onThumbnail: {
                                                self.projectToThumbnail = project
                                            })
                                        }
                                    }
                                    .padding(.bottom, 16)
                                }
                            }
                            .frame(width: 840)
                            .background(expandedNotExportedDays.contains(group.id) ? Color.white.opacity(0.04) : Color.clear)
                            .cornerRadius(16)
                            .padding(.bottom, 8)
                                Spacer()
                            }
                        }
                    }
                    
                    if !exportedGroups.isEmpty {
                        HStack {
                            Spacer()
                            Text("Projects (Exported)").font(.title3).bold().foregroundColor(.gray).frame(width: 820, alignment: .leading)
                            Spacer()
                        }
                        .padding(.top, 16).padding(.bottom, 4)
                        
                        ForEach(exportedGroups) { group in
                            HStack {
                                Spacer()
                                VStack(spacing: 0) {
                                Button(action: {
                                    if expandedExportedDays.contains(group.id) {
                                        expandedExportedDays.remove(group.id)
                                    } else {
                                        expandedExportedDays.insert(group.id)
                                    }
                                }) {
                                    HStack {
                                        Spacer()
                                        HStack {
                                            Image(systemName: expandedExportedDays.contains(group.id) ? "chevron.down" : "chevron.right")
                                                .foregroundColor(.gray)
                                                .frame(width: 20)
                                            Text(group.dateStr).font(.title2).bold().foregroundColor(.white)
                                        }
                                        .padding(.vertical, 14).padding(.horizontal, 20)
                                        .frame(width: 820, alignment: .leading)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.4), lineWidth: 1))
                                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 8)
                                
                                if expandedExportedDays.contains(group.id) {
                                    VStack(spacing: 0) {
                                        ForEach(group.projects, id: \.id) { project in
                                            ProjectExportRow(project: project, onThumbnail: {
                                                self.projectToThumbnail = project
                                            })
                                        }
                                    }
                                    .padding(.bottom, 16)
                                }
                            }
                            .frame(width: 840)
                            .background(expandedExportedDays.contains(group.id) ? Color.white.opacity(0.04) : Color.clear)
                            .cornerRadius(16)
                            .padding(.bottom, 8)
                                Spacer()
                            }
                        }
                    }
                    
                    if !failedJobs.isEmpty {
                        HStack {
                            Spacer()
                            Text("Failed / Cancelled").font(.title3).bold().foregroundColor(.gray).frame(width: 820, alignment: .leading)
                            Spacer()
                        }
                        .padding(.top, 16).padding(.bottom, 4)
                        
                        ForEach(failedJobs) { job in
                            FailedExportRow(job: job)
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .onAppear {
                if !didInitializeExpansions {
                    let notExportedGroups = groupProjectsByDay(projectManager.projects.filter { !Set(manager.jobs.filter { $0.status == .completed }.map { $0.projectName }).contains($0.title) }, prefix: "not_exported")
                    let exportedGroups = groupProjectsByDay(projectManager.projects.filter { Set(manager.jobs.filter { $0.status == .completed }.map { $0.projectName }).contains($0.title) }, prefix: "exported")
                    
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
            if showSettings {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { showSettings = false }
                    .zIndex(102)
                
                ExporterSettingsView(isPresented: $showSettings)
                    .zIndex(103)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            
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
        .frame(minWidth: 800, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
    }
}

struct ActiveExportRow: View {
    var job: ExportJob
    @ObservedObject var manager = ExportManager.shared
    
    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.projectName.capitalized)
                            .font(.title3)
                            .bold()
                            .lineLimit(1)
                        Text("\(job.resolution) • \(job.format) • \(job.bitrate) Bitrate")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 580, alignment: .leading)
                    
                    Button(action: {
                        manager.cancelJob(id: job.id)
                    }) {
                        Text("Cancel")
                            .font(.body)
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
                        .font(.body)
                        .foregroundColor(.gray)
                }
            }
            .padding(12)
            .frame(width: 760, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct QueuedExportRow: View {
    var job: ExportJob
    @ObservedObject var manager = ExportManager.shared
    
    var body: some View {
        HStack {
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.projectName.capitalized)
                        .font(.title3)
                        .bold()
                        .lineLimit(1)
                    Text("\(job.resolution) • \(job.format) • Priority: \(job.priority == .high ? "High" : job.priority == .low ? "Low" : "Normal")")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .frame(width: 580, alignment: .leading)
                
                Button(action: {
                    manager.cancelJob(id: job.id)
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(width: 760, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct CompletedExportRow: View {
    var job: ExportJob
    var onPublish: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.projectName.capitalized)
                        .font(.title3)
                        .bold()
                        .lineLimit(1)
                    Text(job.outputURL.lastPathComponent)
                        .font(.body)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .frame(width: 580, alignment: .leading)
                
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
            .padding(12)
            .frame(width: 760, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct FailedExportRow: View {
    var job: ExportJob
    @ObservedObject var manager = ExportManager.shared
    
    var body: some View {
        HStack {
            Spacer()
            HStack {
                Image(systemName: job.status == .cancelled ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(job.status == .cancelled ? .gray : .red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.projectName.capitalized)
                        .font(.title3)
                        .bold()
                        .lineLimit(1)
                    if let err = job.error {
                        Text(err)
                            .font(.body)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                .frame(width: 580, alignment: .leading)
                
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
            .padding(12)
            .frame(width: 760, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ProjectExportRow: View {
    var project: ProjectState
    var onThumbnail: () -> Void
    
    @ObservedObject var settingsManager = ExportSettingsManager.shared
    @State private var outputPath = ""
    
    var body: some View {
        HStack {
            Spacer()
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                Text(project.title.capitalized)
                    .font(.title3)
                    .bold()
                    .lineLimit(1)
                    .frame(width: 540, alignment: .leading)
                
                Spacer()
                
                Button(action: {
                    onThumbnail()
                }) {
                    Image(systemName: "photo.artframe")
                        .font(.title3)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    queueProjectDirectly()
                }) {
                    Text("Add Queue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(width: 760, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func queueProjectDirectly() {
        let ext = settingsManager.settings.format == "MOV" ? "mov" : "mp4"
        let sanitizedName = project.title.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
        var projectName = sanitizedName
        if projectName.isEmpty || projectName == "Untitled Project" || projectName == "New Project" {
            projectName = project.audioURL?.deletingPathExtension().lastPathComponent ?? "OneLyrics_Export"
        }
        
        let directory: String
        if !outputPath.isEmpty {
            directory = URL(fileURLWithPath: outputPath).deletingLastPathComponent().path
        } else {
            directory = NSHomeDirectory() + "/Desktop"
        }
        let finalPath = directory + "/\(projectName).\(ext)"
        
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
            format: settingsManager.settings.format,
            resolution: settingsManager.settings.resolution,
            bitrate: settingsManager.settings.bitrate,
            outputURL: url,
            publishToYouTube: settingsManager.settings.uploadToYouTube,
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

struct ExporterSettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settingsManager = ExportSettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Export Settings")
                    .font(.title3)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Format").foregroundColor(.gray).font(.caption.weight(.semibold))
                Picker("", selection: $settingsManager.settings.format) {
                    Text("MP4 (H.264)").tag("MP4")
                    Text("MOV (ProRes)").tag("MOV")
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution").foregroundColor(.gray).font(.caption.weight(.semibold))
                Picker("", selection: $settingsManager.settings.resolution) {
                    Text("1080p").tag("1080p")
                    Text("4K").tag("4K")
                    Text("Vertical (9:16)").tag("Vertical")
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Quality / Bitrate").foregroundColor(.gray).font(.caption.weight(.semibold))
                Picker("", selection: $settingsManager.settings.bitrate) {
                    Text("Standard").tag("Standard")
                    Text("High").tag("High")
                    Text("Lossless").tag("Lossless")
                }
                .pickerStyle(.segmented)
            }
            
            Toggle("Generate YouTube Assets (Metadata & Thumbnail)", isOn: $settingsManager.settings.uploadToYouTube)
                .font(.body)
                .foregroundColor(.white)
                .tint(.red)
                .padding(.top, 5)
        }
        .padding(20)
        .frame(width: 350)
        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}
