import Foundation
import Combine
import SwiftUI
import UserNotifications

enum ExportJobStatus: String, Codable, Equatable {
    case queued
    case exporting
    case paused
    case completed
    case failed
    case cancelled
}

enum ExportPriority: Int, Codable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    
    static func < (lhs: ExportPriority, rhs: ExportPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

struct ExportJob: Identifiable, Codable {
    var id: UUID = UUID()
    var projectName: String
    var stateSnapshot: ProjectState
    var durationMs: Double
    var format: String
    var resolution: String
    var bitrate: String
    var outputURL: URL
    
    var status: ExportJobStatus = .queued
    var priority: ExportPriority = .normal
    var progress: Double = 0.0
    var error: String? = nil
    var createdAt: Date = Date()
    var completedAt: Date? = nil
    var publishToYouTube: Bool = false
}

class ExportManager: ObservableObject {
    static let shared = ExportManager()
    
    @Published var jobs: [ExportJob] = []
    
    private var currentExporter: VideoExporter?
    private var cancellables = Set<AnyCancellable>()
    private var isProcessing = false
    
    var isWorker = false
    
    private let queueFileURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Documents")
        .appendingPathComponent("OneLyricsNative")
        .appendingPathComponent("export_queue.json")
    
    init() {
        loadQueue()
        // Mark interrupted jobs as failed on startup (only worker should really do this, but harmless)
        for i in 0..<jobs.count {
            if jobs[i].status == .exporting || jobs[i].status == .paused {
                jobs[i].status = .failed
                jobs[i].error = "Interrupted during export"
            }
        }
        
        startPolling()
    }
    
    private func startPolling() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.loadQueue()
            
            if self.isWorker && !self.isProcessing {
                self.processNextIfAvailable()
            }
        }
    }
    
    func startProcessing() {
        isWorker = true
        processNextIfAvailable()
    }
    
    func addJob(projectName: String, state: ProjectState, durationMs: Double, format: String, resolution: String, bitrate: String, outputURL: URL, publishToYouTube: Bool = false, priority: ExportPriority = .normal) {
        let job = ExportJob(
            projectName: projectName,
            stateSnapshot: state,
            durationMs: durationMs,
            format: format,
            resolution: resolution,
            bitrate: bitrate,
            outputURL: outputURL,
            priority: priority,
            publishToYouTube: publishToYouTube
        )
        DispatchQueue.main.async {
            self.loadQueue()
            self.jobs.append(job)
            self.saveQueue()
            self.processNextIfAvailable()
        }
    }
    
    func launchExporterApp() {
        let workspace = NSWorkspace.shared
        // Try to find if it's already running
        let runningApps = workspace.runningApplications
        if let existingApp = runningApps.first(where: { $0.localizedName == "OneLyricsExporter" }) {
            existingApp.activate(options: .activateIgnoringOtherApps)
            return
        }
        
        // Try to launch by bundle name if it's installed
        if let appURL = workspace.urlForApplication(withBundleIdentifier: "com.onelyrics.exporter") ?? workspace.urlForApplication(withBundleIdentifier: "OneLyricsExporter") {
            try? workspace.launchApplication(at: appURL, options: [], configuration: [:])
            return
        }
        
        // Fallback: spawn process from same location
        let executablePath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments.first!
        let process = Process()
        
        // Check if we are running from .app bundle
        let exporterAppPath = URL(fileURLWithPath: executablePath)
            .deletingLastPathComponent() // MacOS
            .deletingLastPathComponent() // Contents
            .deletingLastPathComponent() // OneLyrics.app
            .deletingLastPathComponent() // release
            .appendingPathComponent("OneLyricsExporter.app")
        
        if FileManager.default.fileExists(atPath: exporterAppPath.path) {
            try? workspace.launchApplication(at: exporterAppPath, options: [], configuration: [:])
        } else {
            // Raw binary fallback
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = ["--exporter"]
            try? process.run()
        }
    }
    
    func cancelJob(id: UUID) {
        if let index = jobs.firstIndex(where: { $0.id == id }) {
            if jobs[index].status == .exporting {
                currentExporter?.cancel()
                currentExporter = nil
                isProcessing = false
            }
            jobs[index].status = .cancelled
            saveQueue()
            processNextIfAvailable()
        }
    }
    
    func retryJob(id: UUID) {
        if let index = jobs.firstIndex(where: { $0.id == id }) {
            jobs[index].status = .queued
            jobs[index].error = nil
            jobs[index].progress = 0
            saveQueue()
            processNextIfAvailable()
        }
    }
    
    func removeJob(id: UUID) {
        cancelJob(id: id)
        jobs.removeAll(where: { $0.id == id })
        saveQueue()
    }
    
    func clearCompleted() {
        jobs.removeAll(where: { $0.status == .completed })
        saveQueue()
    }
    
    private func processNextIfAvailable() {
        guard isWorker, !isProcessing else { return }
        
        let eligibleJobs = jobs.filter { $0.status == .queued }
            .sorted { (job1, job2) in
                if job1.priority != job2.priority {
                    return job1.priority > job2.priority // High priority first
                }
                return job1.createdAt < job2.createdAt // Oldest first
            }
        
        guard let nextJob = eligibleJobs.first else { return }
        startExport(job: nextJob)
    }
    
    private func startExport(job: ExportJob) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        
        isProcessing = true
        jobs[index].status = .exporting
        jobs[index].progress = 0
        saveQueue()
        
        let exporter = VideoExporter()
        self.currentExporter = exporter
        
        exporter.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] p in
                if let idx = self?.jobs.firstIndex(where: { $0.id == job.id }) {
                    self?.jobs[idx].progress = p
                }
            }
            .store(in: &cancellables)
            
        exporter.$isExporting
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] isExporting in
                guard let self = self else { return }
                if !isExporting {
                    if let idx = self.jobs.firstIndex(where: { $0.id == job.id }) {
                        if self.jobs[idx].status == .cancelled {
                            // Already cancelled manually
                        } else if let error = exporter.exportError {
                            self.jobs[idx].status = .failed
                            self.jobs[idx].error = error
                        } else if let _ = exporter.exportedURL {
                            self.jobs[idx].status = .completed
                            self.jobs[idx].completedAt = Date()
                            self.showNotification(title: "Export Complete", body: "\(job.projectName) has finished exporting.")
                            
                            // Send to YouTube Queue if needed
                            if self.jobs[idx].publishToYouTube {
                                // YTDLManager logic for later
                            }
                        }
                    }
                    self.currentExporter = nil
                    self.cancellables.removeAll()
                    self.isProcessing = false
                    self.saveQueue()
                    self.processNextIfAvailable()
                }
            }
            .store(in: &cancellables)
            
        // Start background export
        exporter.export(
            state: job.stateSnapshot,
            durationMs: job.durationMs,
            format: job.format,
            resolution: job.resolution,
            bitrate: job.bitrate,
            outputURL: job.outputURL
        )
    }
    
    private func showNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
    
    // Persistence
    private func saveQueue() {
        let dir = queueFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(jobs) {
            try? data.write(to: queueFileURL)
        }
    }
    
    private func loadQueue() {
        if let data = try? Data(contentsOf: queueFileURL),
           let loaded = try? JSONDecoder().decode([ExportJob].self, from: data) {
            
            if isWorker && isProcessing {
                let activeJobs = self.jobs.filter { $0.status == .exporting || $0.status == .paused }
                var merged = loaded.filter { diskJob in !activeJobs.contains(where: { $0.id == diskJob.id }) }
                merged.append(contentsOf: activeJobs)
                self.jobs = merged
            } else {
                self.jobs = loaded
            }
        }
    }
}
