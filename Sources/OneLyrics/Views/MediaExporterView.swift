import SwiftUI

struct MediaExporterView: View {
    @ObservedObject var manager = ExportManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showYouTubePublish = false
    @State private var selectedVideoURL: URL? = nil
    
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
                if manager.jobs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No items in queue")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
                    .listRowBackground(Color.clear)
                } else {
                    let activeJobs = manager.jobs.filter { $0.status == .exporting || $0.status == .paused }
                    let queuedJobs = manager.jobs.filter { $0.status == .queued }.sorted { $0.priority > $1.priority }
                    let completedJobs = manager.jobs.filter { $0.status == .completed }.sorted { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) }
                    let failedJobs = manager.jobs.filter { $0.status == .failed || $0.status == .cancelled }
                    
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
                        Section(header: Text("Completed").font(.subheadline).foregroundColor(.gray)) {
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
