import SwiftUI
import Combine
import UniformTypeIdentifiers

struct FileListView: View {
    @StateObject private var directoryState: DirectoryState
    @StateObject private var operationsService = FileOperationsService()
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @Binding var selectedURL: URL?
    let onFileSystemChange: (() -> Void)?
    
    @State private var showingNewFolderDialog = false
    @State private var showingNewFileDialog = false
    @State private var showingRenameDialog = false
    @State private var itemToRename: FileSystemItem?
    
    init(initialURL: URL? = nil, selectedURL: Binding<URL?>, onFileSystemChange: (() -> Void)? = nil) {
        let url = initialURL ?? FileManager.default.homeDirectoryForCurrentUser
        self._directoryState = StateObject(wrappedValue: DirectoryState(url: url))
        self._selectedURL = selectedURL
        self.onFileSystemChange = onFileSystemChange
    }
    
    var body: some View {
        VStack(spacing: 0) {
            FileListToolbar(directoryState: directoryState)
            
            FileOperationsToolbar(
                selectedItems: Array(directoryState.selectedItems),
                onCopy: copySelectedItems,
                onCut: cutSelectedItems,
                onPaste: pasteItems,
                onDelete: deleteSelectedItems,
                onRename: renameSelectedItem,
                onNewFolder: { showingNewFolderDialog = true },
                onNewFile: { showingNewFileDialog = true }
            )
            
            ZStack {
                if directoryState.isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    FileListContent(directoryState: directoryState, selectedURL: $selectedURL, onFileSystemChange: onFileSystemChange)
                }
                
                VStack {
                    Spacer()
                    OperationProgressView(operationsService: operationsService)
                }
            }
        }
        .onChange(of: selectedURL) { newURL in
            if let url = newURL, url != directoryState.currentURL {
                directoryState.navigateToURL(url)
            }
        }
        .sheet(isPresented: $showingNewFolderDialog) {
            NewItemDialog(
                isPresented: $showingNewFolderDialog,
                parentURL: directoryState.currentURL,
                itemType: .folder,
                onCreate: createFolder
            )
        }
        .sheet(isPresented: $showingNewFileDialog) {
            NewItemDialog(
                isPresented: $showingNewFileDialog,
                parentURL: directoryState.currentURL,
                itemType: .file,
                onCreate: createFile
            )
        }
        .sheet(isPresented: $showingRenameDialog) {
            if let item = itemToRename {
                RenameDialog(
                    isPresented: $showingRenameDialog,
                    item: item,
                    onRename: { newName in
                        renameItem(item, to: newName)
                    }
                )
            }
        }
    }
    
    private func copySelectedItems() {
        clipboardManager.copy(Array(directoryState.selectedItems))
    }
    
    private func cutSelectedItems() {
        clipboardManager.cut(Array(directoryState.selectedItems))
    }
    
    private func pasteItems() {
        Task {
            do {
                try await operationsService.paste(
                    from: clipboardManager,
                    to: directoryState.currentURL
                )
                await directoryState.refreshCurrentDirectory()
            } catch {
                directoryState.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func deleteSelectedItems() {
        Task {
            do {
                print("Deleting \(directoryState.selectedItems.count) items")
                try await operationsService.moveToTrash(items: Array(directoryState.selectedItems))
                directoryState.clearSelection()
                print("Delete operation completed, refreshing directory")
                await directoryState.refreshCurrentDirectory()
                onFileSystemChange?()
                print("Directory refreshed")
            } catch {
                print("Delete operation failed: \(error)")
                directoryState.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func renameSelectedItem() {
        if let item = directoryState.selectedItems.first {
            itemToRename = item
            showingRenameDialog = true
        }
    }
    
    private func createFolder(name: String) {
        Task {
            do {
                try await operationsService.createFolder(named: name, in: directoryState.currentURL)
                await directoryState.refreshCurrentDirectory()
                onFileSystemChange?()
            } catch {
                directoryState.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func createFile(name: String) {
        Task {
            do {
                print("Creating file '\(name)' in directory: \(directoryState.currentURL.path)")
                try await operationsService.createFile(named: name, in: directoryState.currentURL)
                print("File creation successful")
                await directoryState.refreshCurrentDirectory()
                onFileSystemChange?()
            } catch {
                print("File creation failed: \(error)")
                directoryState.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func renameItem(_ item: FileSystemItem, to newName: String) {
        Task {
            do {
                try await operationsService.rename(item: item, to: newName)
                directoryState.clearSelection()
                await directoryState.refreshCurrentDirectory()
            } catch {
                directoryState.errorMessage = error.localizedDescription
            }
        }
    }
}

struct FileListToolbar: View {
    @ObservedObject var directoryState: DirectoryState
    
    var body: some View {
        HStack {
            Button(action: {
                directoryState.navigateUp()
            }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(directoryState.currentURL.pathComponents.count <= 1)
            
            Button(action: {
                Task {
                    await directoryState.refreshCurrentDirectory()
                }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(BorderlessButtonStyle())
            
            Spacer()
            
            BreadcrumbView(currentURL: directoryState.currentURL) { url in
                directoryState.navigateToURL(url)
            }
            
            Spacer()
            
            Picker("Sort", selection: $directoryState.sortOrder) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 100)
            
            Button(action: {
                directoryState.sortDirection = directoryState.sortDirection == .ascending ? .descending : .ascending
            }) {
                Image(systemName: directoryState.sortDirection == .ascending ? "arrow.up" : "arrow.down")
            }
            .buttonStyle(BorderlessButtonStyle())
            
            Toggle("Hidden", isOn: $directoryState.showHiddenFiles)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct FileListContent: View {
    @ObservedObject var directoryState: DirectoryState
    @Binding var selectedURL: URL?
    let onFileSystemChange: (() -> Void)?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(directoryState.items, id: \.id) { item in
                    FileItemRow(
                        item: item,
                        isSelected: directoryState.selectedItems.contains(item),
                        directoryState: directoryState,
                        selectedURL: $selectedURL,
                        onFileSystemChange: onFileSystemChange
                    )
                }
            }
        }
        .dropDestination(for: URL.self) { urls, location in
            let droppedItems = urls.compactMap { url in
                FileSystemItem(url: url)
            }
            handleDrop(droppedItems, to: nil)
            return true
        }
    }
    
    private func handleDrop(_ items: [FileSystemItem], to target: FileSystemItem?) {
        let destinationURL = target?.url ?? directoryState.currentURL
        
        Task {
            do {
                let operationsService = FileOperationsService()
                try await operationsService.move(items: items, to: destinationURL)
                print("Drag & drop completed in FileListContent, refreshing views")
                
                // Post global notification to refresh all directory views
                await MainActor.run {
                    NotificationCenter.default.post(name: .fileSystemDidChange, object: nil)
                }
                
                // Also trigger the legacy callback
                onFileSystemChange?()
                
                // Small delay then post another notification to catch any delayed updates
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                await MainActor.run {
                    NotificationCenter.default.post(name: .fileSystemDidChange, object: nil)
                }
            } catch {
                print("Drag & drop failed in FileListContent: \(error)")
                directoryState.errorMessage = error.localizedDescription
            }
        }
    }
    
}

struct FileItemRow: View {
    let item: FileSystemItem
    let isSelected: Bool
    @ObservedObject var directoryState: DirectoryState
    @Binding var selectedURL: URL?
    let onFileSystemChange: (() -> Void)?
    
    var body: some View {
        DragAndDropFileRow(
            item: item,
            isSelected: isSelected,
            onSelection: { item in
                directoryState.toggleSelection(item)
            },
            onDoubleClick: handleDoubleClick,
            onDrop: { droppedItems, targetItem in
                handleDrop(droppedItems, to: targetItem)
            }
        )
    }
    
    private func handleDoubleClick(_ item: FileSystemItem) {
        print("Double-clicked on: \(item.name), type: \(item.type)")
        
        // Double-check if it's a directory
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: item.url.path, isDirectory: &isDirectory)
        print("File exists: \(exists), isDirectory: \(isDirectory.boolValue)")
        
        if item.type == .directory || isDirectory.boolValue {
            // Special handling for .app bundles - launch them instead of navigating
            if item.name.hasSuffix(".app") {
                print("Launching application: \(item.name)")
                NSWorkspace.shared.openApplication(at: item.url, configuration: NSWorkspace.OpenConfiguration()) { app, error in
                    if let error = error {
                        print("Failed to launch app: \(error)")
                    } else {
                        print("Successfully launched app: \(item.name)")
                    }
                }
            } else {
                print("Navigating to directory: \(item.url.path)")
                selectedURL = item.url
                directoryState.navigateToURL(item.url)
            }
        } else {
            print("Opening file: \(item.name)")
            // Don't change selectedURL for files - stay in current directory
            openFile(item)
        }
    }
    
    private func openFile(_ item: FileSystemItem) {
        print("Opening file: \(item.name)")
        print("File path: \(item.url.path)")
        print("File exists: \(FileManager.default.fileExists(atPath: item.url.path))")
        print("Is readable: \(FileManager.default.isReadableFile(atPath: item.url.path))")
        
        // Clear any previous error messages immediately
        directoryState.errorMessage = nil
        
        let workspace = NSWorkspace.shared
        
        // For images, let's try a more specific approach
        if let contentType = item.contentType,
           contentType.conforms(to: .image) {
            print("Opening image file")
            
            // Try multiple approaches for images
            if workspace.open(item.url) {
                print("Successfully opened image with default method")
                directoryState.errorMessage = nil // Clear any previous errors
                return
            }
            
            // Try with Preview specifically
            let previewURL = URL(fileURLWithPath: "/System/Applications/Preview.app")
            if FileManager.default.fileExists(atPath: previewURL.path) {
                workspace.open([item.url], withApplicationAt: previewURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                    if let error = error {
                        print("Failed to open with Preview: \(error)")
                        DispatchQueue.main.async {
                            workspace.activateFileViewerSelecting([item.url])
                        }
                    } else {
                        print("Successfully opened with Preview")
                        DispatchQueue.main.async {
                            self.directoryState.errorMessage = nil // Clear any previous errors
                        }
                    }
                }
                return
            }
        }
        
        // For all other files, try the standard approach
        let success = workspace.open(item.url)
        print("Open file result: \(success)")
        
        if success {
            // Clear any previous error messages when file opens successfully
            directoryState.errorMessage = nil
        } else {
            print("Direct open failed, trying to reveal in Finder")
            workspace.activateFileViewerSelecting([item.url])
        }
    }
    
    private func handleDrop(_ items: [FileSystemItem], to target: FileSystemItem?) {
        let destinationURL = target?.url ?? directoryState.currentURL
        
        Task {
            do {
                let operationsService = FileOperationsService()
                try await operationsService.move(items: items, to: destinationURL)
                print("Drag & drop completed in FileItemRow, refreshing views")
                
                // Post global notification to refresh all directory views
                await MainActor.run {
                    NotificationCenter.default.post(name: .fileSystemDidChange, object: nil)
                }
                
                // Also trigger the legacy callback
                onFileSystemChange?()
                
                // Small delay then post another notification to catch any delayed updates
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                await MainActor.run {
                    NotificationCenter.default.post(name: .fileSystemDidChange, object: nil)
                }
            } catch {
                print("Drag & drop failed in FileItemRow: \(error)")
                directoryState.errorMessage = error.localizedDescription
            }
        }
    }
}

struct FileListRow: View {
    let item: FileSystemItem
    let isSelected: Bool
    let onSelection: (FileSystemItem) -> Void
    let onDoubleClick: (FileSystemItem) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            FileIconView(item: item)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                if item.type != .directory {
                    Text(item.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(DateFormatter.fileList.string(from: item.dateModified))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 2) {
                    if !item.isReadable {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    if !item.isWritable {
                        Image(systemName: "lock")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            Rectangle()
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .onTapGesture {
            onSelection(item)
        }
        .onTapGesture(count: 2) {
            onDoubleClick(item)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct BreadcrumbView: View {
    let currentURL: URL
    let onNavigate: (URL) -> Void
    
    var pathComponents: [(String, URL)] {
        var components: [(String, URL)] = []
        var url = currentURL
        
        while url.pathComponents.count > 1 {
            let name = url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent
            components.insert((name, url), at: 0)
            url = url.deletingLastPathComponent()
        }
        
        return components
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                    Button(action: {
                        onNavigate(component.1)
                    }) {
                        Text(component.0)
                            .font(.caption)
                            .foregroundColor(index == pathComponents.count - 1 ? .primary : .secondary)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    if index < pathComponents.count - 1 {
                        Text(" ▶ ")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: 200)
    }
}

extension DateFormatter {
    static let fileList: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}