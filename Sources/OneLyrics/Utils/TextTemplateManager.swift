import SwiftUI
import AppKit

class TextTemplateManager: ObservableObject {
    static let shared = TextTemplateManager()
    @Published var templates: [String] = []
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "UserTextTemplates"),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            self.templates = list
        }
    }
    
    func addTemplate(_ text: String) {
        if !templates.contains(text) {
            templates.append(text)
            save()
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: "UserTextTemplates")
        }
    }
}

struct TextTemplateMenuItems: View {
    @ObservedObject var manager = TextTemplateManager.shared
    
    var body: some View {
        if manager.templates.isEmpty {
            Text("No Templates Available")
        } else {
            ForEach(manager.templates, id: \.self) { text in
                Button(action: {
                    NotificationCenter.default.post(name: .addTextTemplateRequested, object: text)
                }) {
                    Text(text)
                }
            }
        }
    }
}

extension Notification.Name {
    static let addTextTemplateRequested = Notification.Name("addTextTemplateRequested")
}

func showCreateTemplateAlert() {
    let alert = NSAlert()
    alert.messageText = "Create Text Template"
    alert.informativeText = "Enter the text for your new template (e.g., your channel name):"
    alert.addButton(withTitle: "Save")
    alert.addButton(withTitle: "Cancel")
    
    let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
    alert.accessoryView = inputTextField
    alert.window.initialFirstResponder = inputTextField
    
    if alert.runModal() == .alertFirstButtonReturn {
        let text = inputTextField.stringValue
        if !text.isEmpty {
            TextTemplateManager.shared.addTemplate(text)
        }
    }
}
