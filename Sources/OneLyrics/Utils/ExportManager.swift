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
    private var currentJobId: UUID? = nil
    private var currentJobCancellables = Set<AnyCancellable>()
    private var isProcessing = false
    
    var isWorker = false
    
    /// Serial queue to synchronize all file I/O to prevent races
    private let fileQueue = DispatchQueue(label: "com.onelyrics.exportmanager.filequeue")
    
    private let queueFileURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Documents")
        .appendingPathComponent("OneLyricsNative")
        .appendingPathComponent("export_queue.json")
    
    init() {
        self.jobs = readDiskJobsUnsafe()
        // Mark interrupted jobs as failed on startup
        for i in 0..<jobs.count {
            if jobs[i].status == .exporting || jobs[i].status == .paused {
                jobs[i].status = .failed
                jobs[i].error = "Interrupted during export"
            }
        }
        saveQueueToDisk()
        startPolling()
    }
    
    private func startPolling() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.mergeFromDisk()
            
            if self.isWorker && !self.isProcessing {
                self.processNextIfAvailable()
            }
        }
    }
    
    func startProcessing() {
        isWorker = true
        processNextIfAvailable()
    }
    
    // MARK: - Adding Jobs (thread-safe)
    
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
        
        // Atomic file-level append: read disk, append, write back — all on the serial file queue
        fileQueue.sync {
            var diskJobs = self.readDiskJobsUnsafe()
            diskJobs.append(job)
            self.writeDiskJobsUnsafe(diskJobs)
        }
        
        // Now merge the new state into our in-memory array
        DispatchQueue.main.async {
            self.mergeFromDisk()
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
            if jobs[index].status == .exporting && currentJobId == id {
                currentExporter?.cancel()
                currentExporter = nil
                currentJobCancellables.removeAll()
                currentJobId = nil
                isProcessing = false
            }
            jobs[index].status = .cancelled
            saveQueueToDisk()
            processNextIfAvailable()
        }
    }
    
    func retryJob(id: UUID) {
        if let index = jobs.firstIndex(where: { $0.id == id }) {
            jobs[index].status = .queued
            jobs[index].error = nil
            jobs[index].progress = 0
            saveQueueToDisk()
            processNextIfAvailable()
        }
    }
    
    func removeJob(id: UUID) {
        cancelJob(id: id)
        jobs.removeAll(where: { $0.id == id })
        saveQueueToDisk()
    }
    
    func clearCompleted() {
        jobs.removeAll(where: { $0.status == .completed })
        saveQueueToDisk()
    }
    
    // MARK: - Processing
    
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
        currentJobId = job.id
        jobs[index].status = .exporting
        jobs[index].progress = 0
        saveQueueToDisk()
        
        let exporter = VideoExporter()
        self.currentExporter = exporter
        
        // Dedicated cancellable set for THIS job only
        var jobCancellables = Set<AnyCancellable>()
        
        let jobId = job.id
        
        exporter.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] p in
                guard let self = self, self.currentJobId == jobId else { return }
                if let idx = self.jobs.firstIndex(where: { $0.id == jobId }) {
                    self.jobs[idx].progress = p
                }
            }
            .store(in: &jobCancellables)
            
        exporter.$isExporting
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] isExporting in
                guard let self = self, self.currentJobId == jobId else { return }
                if !isExporting {
                    if let idx = self.jobs.firstIndex(where: { $0.id == jobId }) {
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
                    self.currentJobId = nil
                    self.currentJobCancellables.removeAll()
                    self.isProcessing = false
                    self.saveQueueToDisk()
                    self.processNextIfAvailable()
                }
            }
            .store(in: &jobCancellables)
        
        self.currentJobCancellables = jobCancellables
            
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
        let script = "display notification \"\(body)\" with title \"\(title)\""
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        try? task.run()
    }
    
    // MARK: - Persistence (Thread-Safe)
    
    /// Save the current in-memory jobs array to disk atomically
    private func saveQueueToDisk() {
        let jobsSnapshot = self.jobs
        fileQueue.async {
            let dir = self.queueFileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(jobsSnapshot) {
                try? data.write(to: self.queueFileURL, options: .atomic)
            }
        }
    }
    
    /// Merge disk state into memory, preserving any in-flight job's progress/status
    private func mergeFromDisk() {
        let diskJobs: [ExportJob] = fileQueue.sync {
            return self.readDiskJobsUnsafe()
        }
        
        guard !diskJobs.isEmpty || !jobs.isEmpty else { return }
        
        // Build merged list: for each job ID that exists on disk or in memory, pick the right version
        var mergedById: [UUID: ExportJob] = [:]
        
        // Start with disk state
        for job in diskJobs {
            mergedById[job.id] = job
        }
        
        // Overlay in-memory state for any job that is currently being actively managed
        for job in jobs {
            if job.status == .exporting && job.id == currentJobId {
                // This is the active export — always keep our in-memory version (has live progress)
                mergedById[job.id] = job
            } else if job.status == .exporting || job.status == .paused {
                // We think it's exporting but it's not OUR current job — keep disk version
                // (this handles stale state from a previous crash)
            }
            // For queued/completed/failed/cancelled — disk is the source of truth
        }
        
        let merged = Array(mergedById.values).sorted { $0.createdAt < $1.createdAt }
        
        if merged != jobs {
            self.jobs = merged
        }
    }
    
    /// Read jobs from disk — MUST be called on fileQueue
    private func readDiskJobsUnsafe() -> [ExportJob] {
        guard let data = try? Data(contentsOf: queueFileURL),
              let loaded = try? JSONDecoder().decode([ExportJob].self, from: data) else {
            return []
        }
        return loaded
    }
    
    /// Write jobs to disk — MUST be called on fileQueue
    private func writeDiskJobsUnsafe(_ jobs: [ExportJob]) {
        let dir = queueFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(jobs) {
            try? data.write(to: queueFileURL, options: .atomic)
        }
    }
}

// Make ExportJob Equatable so we can compare arrays for change detection
extension ExportJob: Equatable {
    static func == (lhs: ExportJob, rhs: ExportJob) -> Bool {
        return lhs.id == rhs.id &&
               lhs.status == rhs.status &&
               lhs.progress == rhs.progress &&
               lhs.error == rhs.error &&
               lhs.completedAt == rhs.completedAt
    }
}
