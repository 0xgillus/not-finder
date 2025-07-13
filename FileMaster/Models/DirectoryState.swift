import Foundation
import Combine

// Global notification for file system changes
extension Notification.Name {
    static let fileSystemDidChange = Notification.Name("fileSystemDidChange")
}

@MainActor
class DirectoryState: ObservableObject {
    @Published var currentURL: URL
    @Published var items: [FileSystemItem] = []
    @Published var selectedItems: Set<FileSystemItem> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showHiddenFiles = false
    @Published var sortOrder: SortOrder = .name
    @Published var sortDirection: SortDirection = .ascending
    
    private let fileSystemService: FileSystemService
    private var cancellables = Set<AnyCancellable>()
    
    init(url: URL? = nil, 
         fileSystemService: FileSystemService = FileSystemService()) {
        // Use actual home directory, not sandboxed version
        self.currentURL = url ?? URL(fileURLWithPath: NSHomeDirectory())
        self.fileSystemService = fileSystemService
        
        print("DirectoryState initialized with: \(self.currentURL.path)")
        
        $currentURL
            .sink { [weak self] url in
                Task { @MainActor in
                    await self?.loadDirectory(url)
                }
            }
            .store(in: &cancellables)
        
        $showHiddenFiles
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshCurrentDirectory()
                }
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest($sortOrder, $sortDirection)
            .dropFirst()
            .sink { [weak self] _, _ in
                self?.sortItems()
            }
            .store(in: &cancellables)
        
        // Listen for global file system changes
        NotificationCenter.default.publisher(for: .fileSystemDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshCurrentDirectory()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadDirectory(_ url: URL) async {
        isLoading = true
        errorMessage = nil
        
        print("DirectoryState loading: \(url.path)")
        
        do {
            let loadedItems = try await fileSystemService.loadDirectory(
                at: url,
                showHidden: showHiddenFiles
            )
            items = loadedItems
            sortItems()
            
            print("DirectoryState loaded \(items.count) items:")
            for item in items.prefix(5) {
                print("  - \(item.name) (\(item.type))")
            }
            if items.count > 5 {
                print("  ... and \(items.count - 5) more")
            }
            
            // Special handling for Applications folder
            if url.path == "/Applications" && items.isEmpty {
                print("Applications folder appears empty, checking permissions...")
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: url.path) {
                    if let contents = try? fileManager.contentsOfDirectory(atPath: url.path) {
                        print("Raw directory contents: \(contents.count) items")
                        for content in contents.prefix(5) {
                            print("  - \(content)")
                        }
                    }
                }
            }
        } catch {
            print("DirectoryState error: \(error)")
            errorMessage = error.localizedDescription
            items = []
        }
        
        isLoading = false
    }
    
    func refreshCurrentDirectory() async {
        print("DirectoryState: Refreshing directory \(currentURL.path)")
        // Small delay to ensure file system operations are complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        await loadDirectory(currentURL)
    }
    
    func navigateToURL(_ url: URL) {
        print("DirectoryState: Navigating to URL: \(url.path)")
        print("DirectoryState: URL exists: \(FileManager.default.fileExists(atPath: url.path))")
        print("DirectoryState: URL is directory: \(url.hasDirectoryPath)")
        currentURL = url
    }
    
    func navigateUp() {
        let parentURL = currentURL.deletingLastPathComponent()
        if parentURL != currentURL {
            navigateToURL(parentURL)
        }
    }
    
    func selectItem(_ item: FileSystemItem) {
        selectedItems.insert(item)
    }
    
    func deselectItem(_ item: FileSystemItem) {
        selectedItems.remove(item)
    }
    
    func toggleSelection(_ item: FileSystemItem) {
        if selectedItems.contains(item) {
            deselectItem(item)
        } else {
            selectItem(item)
        }
    }
    
    func clearSelection() {
        selectedItems.removeAll()
    }
    
    private func sortItems() {
        items.sort { lhs, rhs in
            let result: Bool
            
            switch sortOrder {
            case .name:
                result = lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .size:
                result = lhs.size < rhs.size
            case .dateModified:
                result = lhs.dateModified < rhs.dateModified
            case .type:
                if lhs.type != rhs.type {
                    return lhs.type == .directory && rhs.type != .directory
                }
                result = lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            
            return sortDirection == .ascending ? result : !result
        }
    }
}

enum SortOrder: String, CaseIterable {
    case name = "Name"
    case size = "Size"
    case dateModified = "Date Modified"
    case type = "Type"
}

enum SortDirection {
    case ascending
    case descending
}