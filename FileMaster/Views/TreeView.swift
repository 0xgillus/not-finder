import SwiftUI
import Combine

struct TreeView: View {
    @StateObject private var treeState = TreeState()
    @Binding var selectedURL: URL?
    let refreshTrigger: UUID
    let onItemSelected: (FileSystemItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TreeNavigationBar(treeState: treeState)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let rootItem = treeState.rootItem {
                        TreeItemView(
                            item: rootItem,
                            level: 0,
                            treeState: treeState,
                            selectedURL: $selectedURL,
                            onItemSelected: onItemSelected
                        )
                    } else if treeState.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if let errorMessage = treeState.errorMessage {
                        Text("Error: \(errorMessage)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
            }
        }
        .frame(minWidth: 200)
        .onAppear {
            Task {
                await treeState.loadInitialTree()
            }
        }
        .onChange(of: refreshTrigger) { _ in
            Task {
                await treeState.refresh()
            }
        }
    }
}

struct TreeNavigationBar: View {
    @ObservedObject var treeState: TreeState
    
    var body: some View {
        HStack {
            Button(action: {
                Task {
                    await treeState.navigateToHome()
                }
            }) {
                Image(systemName: "house")
            }
            .buttonStyle(BorderlessButtonStyle())
            
            Button(action: {
                Task {
                    await treeState.refresh()
                }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(BorderlessButtonStyle())
            
            Spacer()
            
            Button(action: {
                treeState.showHiddenFiles.toggle()
            }) {
                Image(systemName: treeState.showHiddenFiles ? "eye.slash" : "eye")
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct TreeItemView: View {
    let item: FileSystemItem
    let level: Int
    @ObservedObject var treeState: TreeState
    @Binding var selectedURL: URL?
    let onItemSelected: (FileSystemItem) -> Void
    
    @State private var isHovered = false
    
    var isSelected: Bool {
        selectedURL == item.url
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                HStack(spacing: 0) {
                    ForEach(0..<level, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 20)
                    }
                    
                    if item.type == .directory {
                        Button(action: {
                            Task {
                                await treeState.toggleExpansion(for: item)
                            }
                        }) {
                            Image(systemName: treeState.isExpanded(item) ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .frame(width: 16, height: 16)
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 16, height: 16)
                    }
                }
                
                FileIconView(item: item)
                    .frame(width: 16, height: 16)
                
                Text(item.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor.opacity(0.3) : 
                         (isHovered ? Color.gray.opacity(0.1) : Color.clear))
            )
            .onTapGesture(count: 2) {
                onItemSelected(item)
                
                if item.type == .directory {
                    // Special handling for .app bundles - launch them
                    if item.name.hasSuffix(".app") {
                        NSWorkspace.shared.openApplication(at: item.url, configuration: NSWorkspace.OpenConfiguration()) { app, error in
                            if let error = error {
                                print("Failed to launch app from tree: \(error)")
                            } else {
                                print("Successfully launched app from tree: \(item.name)")
                            }
                        }
                    } else {
                        // For regular directories, navigate to them and expand
                        selectedURL = item.url
                        Task {
                            await treeState.toggleExpansion(for: item)
                        }
                    }
                } else {
                    // For files, open them but don't change selectedURL
                    NSWorkspace.shared.open(item.url)
                    print("Opened file from tree: \(item.name)")
                }
            }
            .onTapGesture {
                if item.type == .directory {
                    selectedURL = item.url
                    onItemSelected(item)
                    Task {
                        await treeState.toggleExpansion(for: item)
                    }
                } else {
                    // For files, just call onItemSelected but don't change selectedURL
                    onItemSelected(item)
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }
            
            if item.type == .directory && treeState.isExpanded(item) {
                if let children = treeState.getChildren(for: item) {
                    ForEach(children, id: \.id) { child in
                        TreeItemView(
                            item: child,
                            level: level + 1,
                            treeState: treeState,
                            selectedURL: $selectedURL,
                            onItemSelected: onItemSelected
                        )
                    }
                } else if treeState.isLoading(item) {
                    HStack {
                        ForEach(0..<(level + 1), id: \.self) { _ in
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 20)
                        }
                        
                        ProgressView()
                            .scaleEffect(0.6)
                        
                        Text("Loading...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }
}

@MainActor
class TreeState: ObservableObject {
    @Published var rootItem: FileSystemItem?
    @Published var expandedItems: Set<URL> = []
    @Published var loadingItems: Set<URL> = []
    @Published var childrenCache: [URL: [FileSystemItem]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showHiddenFiles = false
    
    private let fileSystemService = FileSystemService()
    
    func loadInitialTree() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Start with actual user home directory
            let homeURL = URL(fileURLWithPath: NSHomeDirectory())
            print("Loading tree from: \(homeURL.path)")
            
            rootItem = try await fileSystemService.loadDirectoryTree(
                at: homeURL,
                maxDepth: 2,
                showHidden: showHiddenFiles
            )
            
            // Add system Applications folder to the tree if not already present
            let applicationsURL = URL(fileURLWithPath: "/Applications")
            if FileManager.default.fileExists(atPath: applicationsURL.path) {
                // Check if Applications is already in the children
                let hasApplications = rootItem?.children?.contains { item in
                    item.url.path == "/Applications" || item.name == "Applications"
                } ?? false
                
                if !hasApplications {
                    do {
                        let applicationsItem = try await fileSystemService.loadDirectoryTree(
                            at: applicationsURL,
                            maxDepth: 1,
                            showHidden: showHiddenFiles
                        )
                        
                        // Add Applications to the root's children
                        if var children = rootItem?.children {
                            children.insert(applicationsItem, at: 0) // Put Applications at the top
                            rootItem?.children = children
                        } else {
                            rootItem?.children = [applicationsItem]
                        }
                    } catch {
                        print("Could not load Applications folder: \(error)")
                    }
                }
            }
            
            if let root = rootItem {
                childrenCache[root.url] = root.children
                print("Loaded \(root.children?.count ?? 0) items from home directory")
            }
        } catch {
            print("Error loading tree: \(error)")
            errorMessage = error.localizedDescription
            
            // Fallback to trying a basic directory if home fails
            do {
                let fallbackURL = URL(fileURLWithPath: "/Users/\(NSUserName())")
                print("Trying fallback: \(fallbackURL.path)")
                rootItem = try await fileSystemService.loadDirectoryTree(
                    at: fallbackURL,
                    maxDepth: 2,
                    showHidden: showHiddenFiles
                )
            } catch {
                print("Fallback also failed: \(error)")
            }
        }
        
        isLoading = false
    }
    
    func navigateToHome() async {
        await loadInitialTree()
    }
    
    func refresh() async {
        expandedItems.removeAll()
        childrenCache.removeAll()
        await loadInitialTree()
    }
    
    func toggleExpansion(for item: FileSystemItem) async {
        if expandedItems.contains(item.url) {
            expandedItems.remove(item.url)
        } else {
            expandedItems.insert(item.url)
            
            if childrenCache[item.url] == nil && item.type == .directory {
                await loadChildren(for: item)
            }
        }
    }
    
    func loadChildren(for item: FileSystemItem) async {
        guard item.type == .directory else { return }
        
        loadingItems.insert(item.url)
        
        do {
            let children = try await fileSystemService.loadDirectory(
                at: item.url,
                showHidden: showHiddenFiles
            )
            childrenCache[item.url] = children.sorted { lhs, rhs in
                if lhs.type != rhs.type {
                    return lhs.type == .directory && rhs.type != .directory
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        loadingItems.remove(item.url)
    }
    
    func isExpanded(_ item: FileSystemItem) -> Bool {
        expandedItems.contains(item.url)
    }
    
    func isLoading(_ item: FileSystemItem) -> Bool {
        loadingItems.contains(item.url)
    }
    
    func getChildren(for item: FileSystemItem) -> [FileSystemItem]? {
        childrenCache[item.url]
    }
}