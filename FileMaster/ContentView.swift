import SwiftUI

struct ContentView: View {
    @State private var selectedURL: URL?
    @State private var isDualPane = false
    @State private var isSearchMode = false
    @State private var refreshTrigger = UUID()
    
    var body: some View {
        HSplitView {
            TreeView(selectedURL: $selectedURL, refreshTrigger: refreshTrigger) { item in
                // Only navigate for directories, not files
                if item.type == .directory {
                    selectedURL = item.url
                }
            }
            .frame(minWidth: 200, maxWidth: 300)
            
            if isSearchMode {
                SearchView(selectedURL: $selectedURL)
                    .frame(minWidth: 400)
            } else if isDualPane {
                DualPaneView(selectedURL: $selectedURL, onFileSystemChange: {
                    refreshTrigger = UUID()
                })
            } else {
                FileListView(
                    initialURL: selectedURL,
                    selectedURL: $selectedURL,
                    onFileSystemChange: {
                        refreshTrigger = UUID()
                    }
                )
                .frame(minWidth: 400)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    isSearchMode.toggle()
                    if !isSearchMode {
                        isDualPane = false
                    }
                }) {
                    Image(systemName: isSearchMode ? "xmark" : "magnifyingglass")
                }
                .help(isSearchMode ? "Exit Search" : "Search")
                
                if !isSearchMode {
                    Button(action: {
                        isDualPane.toggle()
                    }) {
                        Image(systemName: isDualPane ? "rectangle.split.2x1" : "rectangle")
                    }
                    .help(isDualPane ? "Single Pane" : "Dual Pane")
                }
                
                Button(action: {
                    selectedURL = FileManager.default.homeDirectoryForCurrentUser
                }) {
                    Image(systemName: "house")
                }
                .help("Home")
                
                Button(action: {
                    selectedURL = URL(fileURLWithPath: "/Applications")
                }) {
                    Image(systemName: "app.gift")
                }
                .help("Applications")
                
                Button(action: {
                    if let url = selectedURL {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "arrow.up.right.square")
                }
                .help("Open in Finder")
                .disabled(selectedURL == nil)
            }
        }
        .onAppear {
            // Initialize with user's actual home directory
            selectedURL = URL(fileURLWithPath: NSHomeDirectory())
            print("ContentView initialized with home: \(NSHomeDirectory())")
        }
    }
}

struct DualPaneView: View {
    @Binding var selectedURL: URL?
    let onFileSystemChange: () -> Void
    @State private var leftPaneURL: URL?
    @State private var rightPaneURL: URL?
    
    var body: some View {
        HSplitView {
            VStack {
                Text("Left Pane")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                
                FileListView(
                    initialURL: leftPaneURL ?? selectedURL,
                    selectedURL: $leftPaneURL,
                    onFileSystemChange: onFileSystemChange
                )
            }
            
            VStack {
                Text("Right Pane")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                
                FileListView(
                    initialURL: rightPaneURL ?? selectedURL,
                    selectedURL: $rightPaneURL,
                    onFileSystemChange: onFileSystemChange
                )
            }
        }
        .onAppear {
            if leftPaneURL == nil {
                leftPaneURL = selectedURL
            }
            if rightPaneURL == nil {
                rightPaneURL = URL(fileURLWithPath: NSHomeDirectory())
            }
        }
        .onChange(of: selectedURL) { newURL in
            if leftPaneURL == nil {
                leftPaneURL = newURL
            }
        }
        .onChange(of: leftPaneURL) { newURL in
            selectedURL = newURL
        }
        .onChange(of: rightPaneURL) { newURL in
            selectedURL = newURL
        }
    }
}

#Preview {
    ContentView()
}