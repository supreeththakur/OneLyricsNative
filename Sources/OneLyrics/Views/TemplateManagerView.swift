import SwiftUI

struct TemplateManagerView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: ProjectStore
    @State private var customTemplates: [String] = []
    @State private var defaultTemplate: String = TemplateManager.defaultTemplate
    let builtInTemplates = TemplateManager.builtInTemplates
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Manage Templates")
                Spacer()
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            
            List {
                Section(header: Text("Built-in Templates").foregroundColor(.gray)) {
                    ForEach(builtInTemplates, id: \.self) { templateName in
                        HStack {
                            Text(templateName)
                            Spacer()
                            Button(action: {
                                TemplateManager.defaultTemplate = templateName
                                defaultTemplate = templateName
                                
                                store.state.templateId = templateName
                                TemplateManager.applyTemplate(templateName, to: &store.state.typography)
                            }) {
                                Image(systemName: defaultTemplate == templateName ? "star.fill" : "star")
                                    .foregroundColor(defaultTemplate == templateName ? .yellow : .gray)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Custom Templates").foregroundColor(.gray)) {
                    if customTemplates.isEmpty {
                        Text("No Custom Templates Saved.")
                            .foregroundColor(.gray)
                            .font(.caption)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(customTemplates, id: \.self) { templateName in
                            HStack {
                                Text(templateName)
                                Spacer()
                                
                                // Set Default Button
                                Button(action: {
                                    TemplateManager.defaultTemplate = templateName
                                    defaultTemplate = templateName
                                    
                                    store.state.templateId = templateName
                                    TemplateManager.applyTemplate(templateName, to: &store.state.typography)
                                }) {
                                    Image(systemName: defaultTemplate == templateName ? "star.fill" : "star")
                                        .foregroundColor(defaultTemplate == templateName ? .yellow : .gray)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 8)
                                
                                // Delete Button
                                Button(action: {
                                    TemplateManager.deleteTemplate(name: templateName)
                                    loadTemplates()
                                    if store.state.templateId == templateName {
                                        store.state.templateId = TemplateManager.defaultTemplate
                                        TemplateManager.applyTemplate(store.state.templateId, to: &store.state.typography)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .frame(width: 300, height: 400)
        .background(Color(red: 0.05, green: 0.05, blue: 0.06))
        .onAppear {
            loadTemplates()
        }
    }
    
    private func loadTemplates() {
        customTemplates = Array(TemplateManager.getCustomTemplates().keys).sorted()
        defaultTemplate = TemplateManager.defaultTemplate
    }
}
