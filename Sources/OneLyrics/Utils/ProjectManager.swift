import Foundation
import SwiftUI

class ProjectManager: ObservableObject {
    @Published var projects: [ProjectState] = []
    
    private let fileManager = FileManager.default
    private var projectsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let appFolder = docs.appendingPathComponent("OneLyrics", isDirectory: true)
        let projectsFolder = appFolder.appendingPathComponent("Projects", isDirectory: true)
        
        if !fileManager.fileExists(atPath: projectsFolder.path) {
            try? fileManager.createDirectory(at: projectsFolder, withIntermediateDirectories: true, attributes: nil)
        }
        
        return projectsFolder
    }
    
    init() {
        loadProjects()
    }
    
    func loadProjects() {
        var loadedProjects: [ProjectState] = []
        
        do {
            let files = try fileManager.contentsOfDirectory(at: projectsDirectory, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                let data = try Data(contentsOf: file)
                let project = try JSONDecoder().decode(ProjectState.self, from: data)
                loadedProjects.append(project)
            }
        } catch {
            print("Failed to load projects: \(error)")
        }
        
        // Sort by last modified (newest first)
        self.projects = loadedProjects.sorted { $0.lastModified > $1.lastModified }
    }
    
    private func uniqueTitle(for title: String, ignoringId: UUID? = nil) -> String {
        var newTitle = title
        var counter = 2
        
        while projects.contains(where: { $0.title.lowercased() == newTitle.lowercased() && $0.id != ignoringId }) {
            newTitle = "\(title) \(counter)"
            counter += 1
        }
        
        return newTitle
    }
    
    func createProject(title: String) -> ProjectState {
        var newProject = ProjectState()
        newProject.title = uniqueTitle(for: title)
        saveProject(newProject)
        loadProjects()
        return newProject
    }
    
    func saveProject(_ project: ProjectState) {
        var projectToSave = project
        projectToSave.lastModified = Date() // Update modified date
        
        do {
            let data = try JSONEncoder().encode(projectToSave)
            let fileURL = projectsDirectory.appendingPathComponent("\(projectToSave.id.uuidString).json")
            try data.write(to: fileURL)
        } catch {
            print("Failed to save project: \(error)")
        }
    }
    
    func renameProject(id: UUID, newTitle: String) {
        if let index = projects.firstIndex(where: { $0.id == id }) {
            var project = projects[index]
            project.title = uniqueTitle(for: newTitle, ignoringId: id)
            saveProject(project)
            loadProjects()
        }
    }
    
    func deleteProject(id: UUID) {
        let fileURL = projectsDirectory.appendingPathComponent("\(id.uuidString).json")
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            loadProjects()
        } catch {
            print("Failed to delete project: \(error)")
        }
    }
}
