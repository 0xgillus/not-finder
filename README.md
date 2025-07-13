# FileMaster - Modern File Manager for macOS

FileMaster is a powerful, native macOS file manager built with SwiftUI that addresses Finder's limitations by combining the best features from Windows Explorer and Linux file managers with modern macOS design principles.

## 🎯 Key Features

### ✅ Implemented Features

#### Core Navigation
- **True Tree View**: Display both folders AND files in unified hierarchical tree with visual connection lines
- **Dual-Pane Interface**: Split view showing two independent directory views with drag-and-drop between panes
- **Single-Pane Mode**: Traditional file browser view for focused navigation

#### File Operations
- **Create**: New folders and files with templates
- **Copy/Cut/Paste**: Full clipboard support with visual feedback
- **Rename**: In-place renaming with validation
- **Delete**: Move to Trash with confirmation dialogs
- **Drag & Drop**: Native drag-and-drop file operations between panes and folders

#### Advanced Search
- **Real-time Search**: Fast, accurate search with live results
- **Advanced Filters**: Filter by file type, date modified, size
- **Search Locations**: Current directory, home, entire system
- **Content Search**: Search inside file contents (planned)
- **Hidden Files**: Toggle to include/exclude hidden files

#### Native macOS Integration
- **Quick Look**: Built-in preview support with spacebar activation
- **Context Menus**: Native right-click menus with system services
- **Drag & Drop**: Full system integration for file operations
- **Keyboard Shortcuts**: Standard macOS shortcuts (⌘C, ⌘V, etc.)

#### Modern UX
- **Dark Mode**: Full support for system appearance
- **Customizable Sorting**: By name, size, date, type with ascending/descending
- **Progress Indicators**: Visual feedback for long-running operations
- **Error Handling**: Graceful error messages and recovery

## 🏗️ Architecture

### Technology Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI with AppKit integration
- **Target**: macOS 13.0+ (Ventura)
- **Architecture**: MVVM with Combine for reactive data flow

### Project Structure
```
FileMaster/
├── Models/
│   ├── FileSystemItem.swift      # Core file/directory representation
│   └── DirectoryState.swift      # Directory navigation state
├── Services/
│   ├── FileSystemService.swift   # File system operations
│   └── FileOperationsService.swift # Copy/move/delete operations
├── Views/
│   ├── ContentView.swift         # Main app layout
│   ├── TreeView.swift           # Hierarchical tree navigation
│   ├── FileListView.swift       # File listing with operations
│   ├── SearchView.swift         # Advanced search interface
│   ├── FileOperationsView.swift # File operation dialogs
│   └── QuickLookView.swift      # Quick Look integration
└── Assets.xcassets/
```

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0 or later
- macOS 13.0 (Ventura) or later
- Swift 5.9+

### Building the Project
1. Open `FileMaster.xcodeproj` in Xcode
2. Select the FileMaster target
3. Build and run (⌘R)

### Permissions
The app requires the following permissions:
- **File System Access**: Read/write access to user-selected files
- **Sandbox**: App sandbox with file access entitlements
- **Downloads Folder**: Access to Downloads directory

## 📖 Usage

### Basic Navigation
- **Tree View**: Click folders to expand/collapse in the left sidebar
- **File List**: Double-click files to open, folders to navigate
- **Dual Pane**: Toggle between single and dual-pane modes
- **Search**: Click search icon or use ⌘F

### File Operations
- **Select**: Click files/folders to select
- **Multi-select**: ⌘-click for multiple selection
- **Copy**: ⌘C or toolbar button
- **Paste**: ⌘V or toolbar button
- **Delete**: Delete key or toolbar button
- **Rename**: Select item and click rename button

### Advanced Features
- **Quick Look**: Select file and press Space
- **Search**: Use advanced filters for precise results
- **Drag & Drop**: Drag files between panes or to folders

## 🎯 Success Criteria

FileMaster successfully addresses the core problems with Finder:

✅ **Faster Performance**: Background operations without UI blocking  
✅ **True Tree View**: Shows files alongside folders in hierarchical view  
✅ **Better Search**: Actually finds files users expect to find  
✅ **Power User Features**: Keyboard shortcuts and batch operations  
✅ **Dual-Pane Interface**: Efficient file operations between locations  
✅ **Native Integration**: Maintains macOS look and feel with system features  

## 🔮 Future Enhancements

### Planned Features
- **Terminal Integration**: Open terminal at current location
- **Custom File Associations**: User-defined file type handling
- **Plugin Architecture**: Extensible functionality
- **Bookmark Management**: Organized favorite locations
- **Session Management**: Save/restore window layouts
- **Themes**: Customizable appearance options
- **Advanced Search**: Content indexing and full-text search

### Performance Optimizations
- **Lazy Loading**: On-demand loading for large directories
- **Background Indexing**: Pre-indexed search capabilities
- **Memory Management**: Efficient handling of large file trees
- **Caching**: Smart caching for frequently accessed directories

## 🤝 Contributing

This is a demonstration project showcasing modern macOS app development with SwiftUI. The codebase demonstrates:

- Clean architecture with separation of concerns
- Reactive programming with Combine
- Native macOS integration patterns
- Performance-conscious file system operations
- Modern SwiftUI best practices

## 📄 License

This project is for demonstration purposes. See the project context for usage guidelines.

---

**FileMaster** - Because file management should be powerful, fast, and elegant. 🚀