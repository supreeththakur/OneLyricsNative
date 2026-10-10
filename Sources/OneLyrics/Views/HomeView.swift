import SwiftUI
import AVFoundation

struct HomeView: View {
    @ObservedObject var projectManager: ProjectManager
    var onSelect: (ProjectState) -> Void
    
    @State private var showingNewProjectDialog = false
    @State private var newProjectTitle = ""
    @State private var renamingProjectId: UUID? = nil
    @State private var renamingProjectTitle = ""
    @State private var selectedTab: ProjectType = .lyrics
    
    let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 20)
    ]
    
    var groupedProjects: [(String, [ProjectState])] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        let filteredProjects = projectManager.projects.filter { $0.type == selectedTab }
        let groups = Dictionary(grouping: filteredProjects) { project -> String in
            let date = project.createdAt
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                return dateFormatter.string(from: date)
            }
        }
        
        return groups.sorted { group1, group2 in
            let date1 = group1.value.first?.createdAt ?? Date.distantPast
            let date2 = group2.value.first?.createdAt ?? Date.distantPast
            return date1 > date2
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OneLyrics")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Create stunning lyric videos.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Tab Selection
                HStack(spacing: 0) {
                    Button(action: { selectedTab = .lyrics }) {
                        Text("Lyrics Project")
                            .font(.system(size: 14, weight: selectedTab == .lyrics ? .bold : .medium))
                            .foregroundColor(selectedTab == .lyrics ? .white : .gray)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(selectedTab == .lyrics ? Color.blue.opacity(0.8) : Color.clear)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { selectedTab = .visualizer }) {
                        Text("Visualizer Project")
                            .font(.system(size: 14, weight: selectedTab == .visualizer ? .bold : .medium))
                            .foregroundColor(selectedTab == .visualizer ? .white : .gray)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(selectedTab == .visualizer ? Color.purple.opacity(0.8) : Color.clear)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                
                Spacer()
                
                Button(action: {
                    newProjectTitle = ""
                    showingNewProjectDialog = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Project")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 40)
            .padding(.horizontal, 40)
            
            // Projects Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(groupedProjects, id: \.0) { group in
                        Section(header: 
                            Text(group.0)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 10)
                                .padding(.bottom, 5)
                        ) {
                            ForEach(group.1) { project in
                                ProjectCard(
                                    project: project,
                                    onSelect: { onSelect(project) },
                                    onRename: {
                                        renamingProjectId = project.id
                                        renamingProjectTitle = project.title
                                    },
                                    onDelete: {
                                        projectManager.deleteProject(id: project.id)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.05, green: 0.05, blue: 0.06))
        .alert("New Project", isPresented: $showingNewProjectDialog) {
            TextField("Project Name", text: $newProjectTitle)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                let input = newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = input.isEmpty ? "New Project" : input
                let project = projectManager.createProject(title: title, type: selectedTab)
                onSelect(project)
            }
        }
        .alert("Rename Project", isPresented: Binding(
            get: { renamingProjectId != nil },
            set: { if !$0 { renamingProjectId = nil } }
        )) {
            TextField("New Name", text: $renamingProjectTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let title = renamingProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty, let id = renamingProjectId {
                    projectManager.renameProject(id: id, newTitle: title)
                }
                renamingProjectId = nil
            }
        }
    }
}

struct ProjectCard: View {
    let project: ProjectState
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: project.lastModified, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail Area
            ProjectThumbnailView(url: project.backgroundURL)
            .overlay(
                // Play button overlay
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .opacity(isHovering ? 1.0 : 0.0)
                    .scaleEffect(isHovering ? 1.0 : 0.8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
            )
            .clipped()
            
            // Info Area
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(formattedDate)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .padding(12)
        }
        .background(Color(white: 0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(isHovering ? 0.2 : 0.05), lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Rename...") { onRename() }
            Button("Delete Project", role: .destructive) { onDelete() }
        }
        // macOS pointer cursor on hover
        .onContinuousHover { phase in
            switch phase {
            case .active(_): NSCursor.pointingHand.push()
            case .ended: NSCursor.pop()
            }
        }
    }
}
