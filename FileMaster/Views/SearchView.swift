import SwiftUI
import Combine

struct SearchView: View {
    @StateObject private var searchState = SearchState()
    @Binding var selectedURL: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            SearchBar(searchState: searchState)
            
            if searchState.isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if searchState.searchResults.isEmpty && !searchState.searchQuery.isEmpty {
                VStack {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try adjusting your search criteria")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                SearchResultsList(
                    results: searchState.searchResults,
                    selectedURL: $selectedURL
                )
            }
        }
    }
}

struct SearchBar: View {
    @ObservedObject var searchState: SearchState
    @State private var isAdvancedSearchExpanded = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search files and folders...", text: $searchState.searchQuery) { _ in
                    Task {
                        await searchState.performSearch()
                    }
                } onCommit: {
                    Task {
                        await searchState.performSearch()
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: {
                    searchState.clearSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
                .opacity(searchState.searchQuery.isEmpty ? 0 : 1)
                
                Button(action: {
                    isAdvancedSearchExpanded.toggle()
                }) {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            if isAdvancedSearchExpanded {
                AdvancedSearchOptions(searchState: searchState)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onChange(of: searchState.searchQuery) { query in
            if !query.isEmpty {
                Task {
                    await searchState.performSearchWithDelay()
                }
            }
        }
    }
}

struct AdvancedSearchOptions: View {
    @ObservedObject var searchState: SearchState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Search in:")
                Picker("Location", selection: $searchState.searchLocation) {
                    Text("Current Directory").tag(SearchLocation.currentDirectory)
                    Text("Home Directory").tag(SearchLocation.homeDirectory)
                    Text("Entire System").tag(SearchLocation.entireSystem)
                    Text("Custom...").tag(SearchLocation.custom)
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            HStack {
                Text("File type:")
                Picker("Type", selection: $searchState.fileTypeFilter) {
                    Text("All").tag(FileTypeFilter.all)
                    Text("Documents").tag(FileTypeFilter.documents)
                    Text("Images").tag(FileTypeFilter.images)
                    Text("Videos").tag(FileTypeFilter.videos)
                    Text("Audio").tag(FileTypeFilter.audio)
                    Text("Applications").tag(FileTypeFilter.applications)
                    Text("Folders").tag(FileTypeFilter.folders)
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            HStack {
                Text("Date modified:")
                Picker("Date", selection: $searchState.dateFilter) {
                    Text("Any time").tag(DateFilter.anytime)
                    Text("Today").tag(DateFilter.today)
                    Text("This week").tag(DateFilter.thisWeek)
                    Text("This month").tag(DateFilter.thisMonth)
                    Text("This year").tag(DateFilter.thisYear)
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            HStack {
                Toggle("Include hidden files", isOn: $searchState.includeHiddenFiles)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                
                Spacer()
                
                Toggle("Search content", isOn: $searchState.searchContent)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            }
        }
        .font(.caption)
    }
}

struct SearchResultsList: View {
    let results: [FileSystemItem]
    @Binding var selectedURL: URL?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(results, id: \.id) { item in
                    SearchResultRow(item: item, selectedURL: $selectedURL)
                }
            }
        }
    }
}

struct SearchResultRow: View {
    let item: FileSystemItem
    @Binding var selectedURL: URL?
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.iconName)
                .font(.system(size: 16))
                .foregroundColor(item.type == .directory ? .accentColor : .primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(item.url.deletingLastPathComponent().path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if item.type != .directory {
                    Text(item.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Text(DateFormatter.fileList.string(from: item.dateModified))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
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
            selectedURL = item.url
        }
        .onTapGesture(count: 2) {
            selectedURL = item.url
            if item.type == .directory {
                
            } else {
                NSWorkspace.shared.open(item.url)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Open") {
                NSWorkspace.shared.open(item.url)
            }
            
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: "")
            }
            
            Divider()
            
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
        }
    }
}

@MainActor
class SearchState: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [FileSystemItem] = []
    @Published var isSearching = false
    @Published var searchLocation: SearchLocation = .currentDirectory
    @Published var fileTypeFilter: FileTypeFilter = .all
    @Published var dateFilter: DateFilter = .anytime
    @Published var includeHiddenFiles = false
    @Published var searchContent = false
    
    private let fileSystemService = FileSystemService()
    private var searchTask: Task<Void, Never>?
    
    func performSearch() async {
        searchTask?.cancel()
        
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            isSearching = true
            
            do {
                let searchDirectory = getSearchDirectory()
                let results = try await fileSystemService.searchFiles(
                    in: searchDirectory,
                    query: searchQuery,
                    includeSubdirectories: true
                )
                
                if !Task.isCancelled {
                    let filteredResults = filterResults(results)
                    searchResults = filteredResults
                }
            } catch {
                if !Task.isCancelled {
                    searchResults = []
                }
            }
            
            if !Task.isCancelled {
                isSearching = false
            }
        }
    }
    
    func performSearchWithDelay() async {
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        if !Task.isCancelled {
            await performSearch()
        }
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchTask?.cancel()
    }
    
    private func getSearchDirectory() -> URL {
        switch searchLocation {
        case .currentDirectory:
            return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        case .homeDirectory:
            return FileManager.default.homeDirectoryForCurrentUser
        case .entireSystem:
            return URL(fileURLWithPath: "/")
        case .custom:
            return FileManager.default.homeDirectoryForCurrentUser
        }
    }
    
    private func filterResults(_ results: [FileSystemItem]) -> [FileSystemItem] {
        var filtered = results
        
        if !includeHiddenFiles {
            filtered = filtered.filter { !$0.isHidden }
        }
        
        switch fileTypeFilter {
        case .all:
            break
        case .documents:
            filtered = filtered.filter { item in
                guard let contentType = item.contentType else { return false }
                return contentType.conforms(to: .text) || contentType.conforms(to: .pdf)
            }
        case .images:
            filtered = filtered.filter { item in
                guard let contentType = item.contentType else { return false }
                return contentType.conforms(to: .image)
            }
        case .videos:
            filtered = filtered.filter { item in
                guard let contentType = item.contentType else { return false }
                return contentType.conforms(to: .video)
            }
        case .audio:
            filtered = filtered.filter { item in
                guard let contentType = item.contentType else { return false }
                return contentType.conforms(to: .audio)
            }
        case .applications:
            filtered = filtered.filter { item in
                guard let contentType = item.contentType else { return false }
                return contentType.conforms(to: .application)
            }
        case .folders:
            filtered = filtered.filter { $0.type == .directory }
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        switch dateFilter {
        case .anytime:
            break
        case .today:
            filtered = filtered.filter { calendar.isDate($0.dateModified, inSameDayAs: now) }
        case .thisWeek:
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            filtered = filtered.filter { $0.dateModified >= weekAgo }
        case .thisMonth:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            filtered = filtered.filter { $0.dateModified >= monthAgo }
        case .thisYear:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            filtered = filtered.filter { $0.dateModified >= yearAgo }
        }
        
        return filtered.sorted { lhs, rhs in
            if lhs.type != rhs.type {
                return lhs.type == .directory && rhs.type != .directory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

enum SearchLocation: String, CaseIterable {
    case currentDirectory = "Current Directory"
    case homeDirectory = "Home Directory"
    case entireSystem = "Entire System"
    case custom = "Custom"
}

enum FileTypeFilter: String, CaseIterable {
    case all = "All"
    case documents = "Documents"
    case images = "Images"
    case videos = "Videos"
    case audio = "Audio"
    case applications = "Applications"
    case folders = "Folders"
}

enum DateFilter: String, CaseIterable {
    case anytime = "Any time"
    case today = "Today"
    case thisWeek = "This week"
    case thisMonth = "This month"
    case thisYear = "This year"
}