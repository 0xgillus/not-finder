import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum FileSystemItemType: Hashable, Equatable {
    case file
    case directory
    case symlink
    case unknown
}

struct FileSystemItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let type: FileSystemItemType
    let size: Int64
    let dateModified: Date
    let dateCreated: Date
    let isHidden: Bool
    let permissions: FilePermissions
    let contentType: UTType?
    
    var children: [FileSystemItem]?
    var isExpanded: Bool = false
    
    static func == (lhs: FileSystemItem, rhs: FileSystemItem) -> Bool {
        return lhs.url == rhs.url
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        
        let resourceValues = try? url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .isHiddenKey,
            .contentTypeKey
        ])
        
        if resourceValues?.isSymbolicLink == true {
            self.type = .symlink
        } else if resourceValues?.isDirectory == true {
            self.type = .directory
        } else if url.hasDirectoryPath {
            self.type = .directory
        } else {
            self.type = .file
        }
        
        // Debug output
        if name.contains("Desktop") || name.contains("Documents") {
            print("FileSystemItem: \(name) - type: \(type), isDirectory: \(resourceValues?.isDirectory ?? false), hasDirectoryPath: \(url.hasDirectoryPath)")
        }
        
        self.size = Int64(resourceValues?.fileSize ?? 0)
        self.dateModified = resourceValues?.contentModificationDate ?? Date()
        self.dateCreated = resourceValues?.creationDate ?? Date()
        self.isHidden = resourceValues?.isHidden ?? false
        self.contentType = resourceValues?.contentType
        
        self.permissions = FilePermissions(url: url)
        
        if self.type == .directory {
            self.children = []
        }
    }
    
    var iconName: String {
        switch type {
        case .directory:
            // Special handling for Applications
            if url.path == "/Applications" {
                return "app.gift"
            }
            // Special handling for .app bundles
            if name.hasSuffix(".app") {
                return "app"
            }
            return "folder"
        case .file:
            if let contentType = contentType {
                if contentType.conforms(to: .image) {
                    return "photo"
                } else if contentType.conforms(to: .video) {
                    return "video"
                } else if contentType.conforms(to: .audio) {
                    return "music.note"
                } else if contentType.conforms(to: .text) {
                    return "doc.text"
                } else if contentType.conforms(to: .pdf) {
                    return "doc.richtext"
                } else if contentType.conforms(to: .application) {
                    return "app"
                }
            }
            return "doc"
        case .symlink:
            return "link"
        case .unknown:
            return "questionmark"
        }
    }
    
    var formattedSize: String {
        if type == .directory {
            return "--"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var isReadable: Bool {
        permissions.readable
    }
    
    var isWritable: Bool {
        permissions.writable
    }
    
    var isExecutable: Bool {
        permissions.executable
    }
}

struct FilePermissions: Hashable, Equatable {
    let readable: Bool
    let writable: Bool
    let executable: Bool
    
    init(url: URL) {
        let fileManager = FileManager.default
        self.readable = fileManager.isReadableFile(atPath: url.path)
        self.writable = fileManager.isWritableFile(atPath: url.path)
        self.executable = fileManager.isExecutableFile(atPath: url.path)
    }
}