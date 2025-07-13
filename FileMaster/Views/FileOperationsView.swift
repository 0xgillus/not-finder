import SwiftUI
import Combine

struct FileOperationsToolbar: View {
    let selectedItems: [FileSystemItem]
    let onCopy: () -> Void
    let onCut: () -> Void
    let onPaste: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void
    let onNewFolder: () -> Void
    let onNewFile: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            Button(action: onNewFolder) {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("New Folder")
            
            Button(action: onNewFile) {
                Image(systemName: "doc.badge.plus")
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("New File")
            
            Divider()
                .frame(height: 16)
            
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Copy")
            .disabled(selectedItems.isEmpty)
            
            Button(action: onCut) {
                Image(systemName: "scissors")
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Cut")
            .disabled(selectedItems.isEmpty)
            
            Button(action: onPaste) {
                Image(systemName: "doc.on.clipboard")
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Paste")
            
            Divider()
                .frame(height: 16)
            
            Button(action: onRename) {
                Image(systemName: "pencil")
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Rename")
            .disabled(selectedItems.count != 1)
            
            Button(action: {
                showingDeleteAlert = true
            }) {
                Image(systemName: "trash")
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Delete")
            .disabled(selectedItems.isEmpty)
            .alert("Delete Items", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive, action: onDelete)
            } message: {
                Text("Are you sure you want to delete \(selectedItems.count) item\(selectedItems.count == 1 ? "" : "s")? This action cannot be undone.")
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct NewItemDialog: View {
    let isPresented: Binding<Bool>
    let parentURL: URL
    let itemType: NewItemType
    let onCreate: (String) -> Void
    
    @State private var itemName = ""
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create New \(itemType.displayName)")
                .font(.headline)
            
            TextField("Name", text: $itemName) { _ in
                createItem()
            } onCommit: {
                createItem()
            }
            .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    isPresented.wrappedValue = false
                }
                .keyboardShortcut(.escape)
                
                Button("Create") {
                    createItem()
                }
                .keyboardShortcut(.return)
                .disabled(itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            itemName = ""
            errorMessage = nil
        }
    }
    
    private func createItem() {
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Name cannot be empty"
            return
        }
        
        let targetURL = parentURL.appendingPathComponent(trimmedName)
        print("NewItemDialog: Creating \(itemType.displayName) with name '\(trimmedName)'")
        print("NewItemDialog: Parent URL: \(parentURL.path)")
        print("NewItemDialog: Target URL: \(targetURL.path)")
        
        let fileExists = FileManager.default.fileExists(atPath: targetURL.path)
        print("NewItemDialog: File exists check: \(fileExists)")
        
        if fileExists {
            errorMessage = "An item with this name already exists"
            return
        }
        
        onCreate(trimmedName)
        isPresented.wrappedValue = false
    }
}

struct RenameDialog: View {
    let isPresented: Binding<Bool>
    let item: FileSystemItem
    let onRename: (String) -> Void
    
    @State private var newName = ""
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename \(item.name)")
                .font(.headline)
            
            TextField("New name", text: $newName) { _ in
                renameItem()
            } onCommit: {
                renameItem()
            }
            .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    isPresented.wrappedValue = false
                }
                .keyboardShortcut(.escape)
                
                Button("Rename") {
                    renameItem()
                }
                .keyboardShortcut(.return)
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            newName = item.name
            errorMessage = nil
        }
    }
    
    private func renameItem() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Name cannot be empty"
            return
        }
        
        guard trimmedName != item.name else {
            isPresented.wrappedValue = false
            return
        }
        
        let parentURL = item.url.deletingLastPathComponent()
        let targetURL = parentURL.appendingPathComponent(trimmedName)
        
        if FileManager.default.fileExists(atPath: targetURL.path) {
            errorMessage = "An item with this name already exists"
            return
        }
        
        onRename(trimmedName)
        isPresented.wrappedValue = false
    }
}

enum NewItemType {
    case folder
    case file
    
    var displayName: String {
        switch self {
        case .folder:
            return "Folder"
        case .file:
            return "File"
        }
    }
}

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published private(set) var clipboardItems: [FileSystemItem] = []
    @Published private(set) var clipboardOperation: ClipboardOperation = .copy
    
    private init() {}
    
    func copy(_ items: [FileSystemItem]) {
        clipboardItems = items
        clipboardOperation = .copy
        
        let urls = items.map { $0.url }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSPasteboardWriting])
    }
    
    func cut(_ items: [FileSystemItem]) {
        clipboardItems = items
        clipboardOperation = .cut
        
        let urls = items.map { $0.url }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSPasteboardWriting])
    }
    
    func clear() {
        clipboardItems.removeAll()
        NSPasteboard.general.clearContents()
    }
    
    var hasItems: Bool {
        !clipboardItems.isEmpty
    }
}

enum ClipboardOperation {
    case copy
    case cut
}