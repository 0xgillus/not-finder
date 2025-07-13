import SwiftUI
import QuickLook
import AppKit

struct QuickLookView: NSViewRepresentable {
    typealias NSViewType = NSView
    
    let url: URL
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Add a text label indicating Quick Look integration
        let label = NSTextField(labelWithString: "Quick Look Preview")
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update if needed
    }
}

struct QuickLookPanel: View {
    let item: FileSystemItem
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button(action: {
                    // Open with system Quick Look
                    openWithQuickLook()
                }) {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Open with Quick Look")
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            VStack {
                Image(systemName: item.iconName)
                    .font(.system(size: 64))
                    .foregroundColor(item.type == .directory ? .accentColor : .primary)
                
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.medium)
                
                if item.type != .directory {
                    Text(item.formattedSize)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Location:")
                            .fontWeight(.medium)
                        Text(item.url.deletingLastPathComponent().path)
                    }
                    HStack {
                        Text("Modified:")
                            .fontWeight(.medium)
                        Text(DateFormatter.fileList.string(from: item.dateModified))
                    }
                    HStack {
                        Text("Created:")
                            .fontWeight(.medium)
                        Text(DateFormatter.fileList.string(from: item.dateCreated))
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                
                if item.type != .directory {
                    Button(action: openWithQuickLook) {
                        HStack {
                            Image(systemName: "eye")
                            Text("Quick Look")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .frame(minWidth: 400, minHeight: 300)
        }
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 8)
    }
    
    private func openWithQuickLook() {
        // Use NSWorkspace to open with Quick Look
        NSWorkspace.shared.open(item.url)
    }
}

extension FileListRow {
    func addQuickLookSupport(item: FileSystemItem, showQuickLook: Binding<Bool>) -> some View {
        self
    }
}

struct DragAndDropFileRow: View {
    let item: FileSystemItem
    let isSelected: Bool
    let onSelection: (FileSystemItem) -> Void
    let onDoubleClick: (FileSystemItem) -> Void
    let onDrop: ([FileSystemItem], FileSystemItem) -> Void
    
    @State private var isHovered = false
    @State private var isDragTarget = false
    @State private var showQuickLook = false
    
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
                .fill(isDragTarget ? Color.accentColor.opacity(0.3) :
                     (isSelected ? Color.accentColor.opacity(0.2) :
                     (isHovered ? Color.gray.opacity(0.1) : Color.clear)))
        )
        .onTapGesture(count: 2) {
            print("DragAndDropFileRow: Double-click detected on \(item.name)")
            onDoubleClick(item)
        }
        .onTapGesture {
            print("DragAndDropFileRow: Single-click detected on \(item.name)")
            onSelection(item)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .draggable(item.url) {
            HStack {
                Image(systemName: item.iconName)
                Text(item.name)
            }
            .padding(4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(4)
        }
        .dropDestination(for: URL.self) { urls, location in
            guard item.type == .directory else { return false }
            
            let droppedItems = urls.compactMap { url in
                FileSystemItem(url: url)
            }
            
            onDrop(droppedItems, item)
            isDragTarget = false
            return true
        } isTargeted: { targeted in
            isDragTarget = targeted && item.type == .directory
        }
        .sheet(isPresented: $showQuickLook) {
            QuickLookPanel(item: item, isPresented: $showQuickLook)
                .frame(minWidth: 500, minHeight: 400)
        }
        .contextMenu {
            Button("Quick Look") {
                if item.type != .directory {
                    NSWorkspace.shared.open(item.url)
                } else {
                    showQuickLook = true
                }
            }
            
            Divider()
            
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

struct FileIconView: View {
    let item: FileSystemItem
    @State private var appIcon: NSImage?
    
    var body: some View {
        Group {
            if let appIcon = appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            } else {
                Image(systemName: item.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(item.type == .directory ? .accentColor : .primary)
            }
        }
        .onAppear {
            loadAppIcon()
        }
    }
    
    private func loadAppIcon() {
        // Try to get the actual file icon for any file/app
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: item.url.path)
            
            // Only use the icon if it's not the generic document icon
            // This helps apps show their real icons while files use system icons
            let genericDocumentIcon = NSWorkspace.shared.icon(for: .data)
            
            DispatchQueue.main.async {
                // For .app files, always use the icon we got
                if item.name.hasSuffix(".app") {
                    self.appIcon = icon
                } else if !icon.isEqual(genericDocumentIcon) {
                    // For other files, only use if it's not the generic icon
                    self.appIcon = icon
                }
            }
        }
    }
}