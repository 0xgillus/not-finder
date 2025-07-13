import Foundation
import Combine

class FileSystemService: ObservableObject, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "FileSystemService", qos: .userInitiated)
    
    enum FileSystemError: LocalizedError {
        case accessDenied(String)
        case directoryNotFound(String)
        case operationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .accessDenied(let path):
                return "Access denied to '\(path)'"
            case .directoryNotFound(let path):
                return "Directory not found: '\(path)'"
            case .operationFailed(let message):
                return "Operation failed: \(message)"
            }
        }
    }
    
    func loadDirectory(at url: URL, showHidden: Bool = false) async throws -> [FileSystemItem] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FileSystemError.operationFailed("Service deallocated"))
                    return
                }
                do {
                    guard self.fileManager.fileExists(atPath: url.path) else {
                        continuation.resume(throwing: FileSystemError.directoryNotFound(url.path))
                        return
                    }
                    
                    print("FileSystemService: Loading directory contents for: \(url.path)")
                    
                    // Special handling for Applications folder to ensure proper app loading
                    let options: FileManager.DirectoryEnumerationOptions = []
                    if url.path == "/Applications" {
                        print("FileSystemService: Special handling for Applications folder")
                        // For Applications folder, don't skip hidden files initially - we'll filter later
                        // This ensures we get all .app bundles properly
                    }
                    
                    let contents = try self.fileManager.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: [
                            .isDirectoryKey,
                            .isSymbolicLinkKey,
                            .fileSizeKey,
                            .contentModificationDateKey,
                            .creationDateKey,
                            .isHiddenKey,
                            .contentTypeKey,
                            .effectiveIconKey,
                            .customIconKey
                        ],
                        options: options
                    )
                    print("FileSystemService: Found \(contents.count) items in \(url.path)")
                    
                    let items = contents.compactMap { itemURL -> FileSystemItem? in
                        let item = FileSystemItem(url: itemURL)
                        
                        // Special case for Applications: show .app bundles even if marked as hidden
                        if url.path == "/Applications" && item.name.hasSuffix(".app") {
                            return item
                        }
                        
                        if !showHidden && item.isHidden {
                            return nil
                        }
                        
                        return item
                    }
                    
                    // Sort with special handling for Applications
                    let sortedItems = items.sorted { lhs, rhs in
                        // In Applications folder, prioritize .app files
                        if url.path == "/Applications" {
                            let lhsIsApp = lhs.name.hasSuffix(".app")
                            let rhsIsApp = rhs.name.hasSuffix(".app")
                            
                            if lhsIsApp != rhsIsApp {
                                return lhsIsApp && !rhsIsApp
                            }
                        }
                        
                        // Standard sorting
                        if lhs.type != rhs.type {
                            return lhs.type == .directory && rhs.type != .directory
                        }
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                    
                    continuation.resume(returning: sortedItems)
                } catch {
                    continuation.resume(throwing: FileSystemError.operationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func loadDirectoryTree(at url: URL, maxDepth: Int = 3, showHidden: Bool = false) async throws -> FileSystemItem {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FileSystemError.operationFailed("Service deallocated"))
                    return
                }
                let rootItem = self.buildDirectoryTree(
                        url: url,
                        currentDepth: 0,
                        maxDepth: maxDepth,
                        showHidden: showHidden
                    )
                    continuation.resume(returning: rootItem)
            }
        }
    }
    
    private func buildDirectoryTree(url: URL, currentDepth: Int, maxDepth: Int, showHidden: Bool) -> FileSystemItem {
        var item = FileSystemItem(url: url)
        
        if item.type == .directory && currentDepth < maxDepth {
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [
                        .isDirectoryKey,
                        .isSymbolicLinkKey,
                        .fileSizeKey,
                        .contentModificationDateKey,
                        .creationDateKey,
                        .isHiddenKey,
                        .contentTypeKey
                    ],
                    options: []
                )
                
                let children = contents.compactMap { childURL -> FileSystemItem? in
                    let childItem: FileSystemItem
                    
                    // Check if this is a directory to decide whether to recurse
                    let resourceValues = try? childURL.resourceValues(forKeys: [.isDirectoryKey])
                    let isDirectory = resourceValues?.isDirectory ?? false
                    
                    if isDirectory && currentDepth < maxDepth - 1 {
                        // Recurse for directories if we haven't reached max depth
                        childItem = self.buildDirectoryTree(
                            url: childURL,
                            currentDepth: currentDepth + 1,
                            maxDepth: maxDepth,
                            showHidden: showHidden
                        )
                    } else {
                        // For files or when at max depth, just create the item without recursing
                        childItem = FileSystemItem(url: childURL)
                    }
                    
                    if !showHidden && childItem.isHidden {
                        return nil
                    }
                    
                    return childItem
                }
                
                item.children = children.sorted { lhs, rhs in
                    if lhs.type != rhs.type {
                        return lhs.type == .directory && rhs.type != .directory
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            } catch {
                item.children = []
            }
        }
        
        return item
    }
    
    func createDirectory(at url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FileSystemError.operationFailed("Service deallocated"))
                    return
                }
                do {
                    try self.fileManager.createDirectory(
                        at: url,
                        withIntermediateDirectories: false,
                        attributes: nil
                    )
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: FileSystemError.operationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func createFile(at url: URL, contents: Data = Data()) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FileSystemError.operationFailed("Service deallocated"))
                    return
                }
                
                print("FileSystemService: Creating file at \(url.path)")
                print("FileSystemService: URL description: \(url)")
                print("FileSystemService: URL absoluteString: \(url.absoluteString)")
                
                // Standardize the URL to ensure proper path resolution
                let standardURL = url.standardizedFileURL
                print("FileSystemService: Standardized URL: \(standardURL.path)")
                
                // Check if parent directory exists
                let parentURL = standardURL.deletingLastPathComponent()
                let parentExists = self.fileManager.fileExists(atPath: parentURL.path)
                print("FileSystemService: Parent directory \(parentURL.path) exists: \(parentExists)")
                
                if !parentExists {
                    print("FileSystemService: Parent directory does not exist: \(parentURL.path)")
                    continuation.resume(throwing: FileSystemError.directoryNotFound(parentURL.path))
                    return
                }
                
                // Check if file already exists using standardized URL
                let fileExists = self.fileManager.fileExists(atPath: standardURL.path)
                print("FileSystemService: Checking if file exists at \(standardURL.path) - Result: \(fileExists)")
                if fileExists {
                    print("FileSystemService: File already exists at \(standardURL.path)")
                    continuation.resume(throwing: FileSystemError.operationFailed("File already exists"))
                    return
                }
                
                let success = self.fileManager.createFile(
                    atPath: standardURL.path,
                    contents: contents,
                    attributes: nil
                )
                
                if success {
                    print("FileSystemService: File created successfully at \(standardURL.path)")
                    continuation.resume()
                } else {
                    print("FileSystemService: Failed to create file at \(standardURL.path)")
                    continuation.resume(throwing: FileSystemError.operationFailed("Failed to create file at \(standardURL.path)"))
                }
            }
        }
    }
    
    func moveItem(from sourceURL: URL, to destinationURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FileSystemError.operationFailed("Service deallocated"))
                    return
                }
                do {
                    try self.fileManager.moveItem(at: sourceURL, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: FileSystemError.operationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func copyItem(from sourceURL: URL, to destinationURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FileSystemError.operationFailed("Service deallocated"))
                    return
                }
                do {
                    try self.fileManager.copyItem(at: sourceURL, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: FileSystemError.operationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func deleteItem(at url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FileSystemError.operationFailed("Service deallocated"))
                    return
                }
                do {
                    try self.fileManager.removeItem(at: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: FileSystemError.operationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func renameItem(at url: URL, to newName: String) async throws {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try await moveItem(from: url, to: newURL)
    }
    
    func searchFiles(in directory: URL, query: String, includeSubdirectories: Bool = true) async throws -> [FileSystemItem] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FileSystemError.operationFailed("Service deallocated"))
                    return
                }
                var results: [FileSystemItem] = []
                let searchOptions: FileManager.DirectoryEnumerationOptions = includeSubdirectories ? [] : [.skipsSubdirectoryDescendants]
                
                if let enumerator = self.fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [
                        .isDirectoryKey,
                        .isSymbolicLinkKey,
                        .fileSizeKey,
                        .contentModificationDateKey,
                        .creationDateKey,
                        .isHiddenKey,
                        .contentTypeKey
                    ],
                    options: searchOptions
                ) {
                    for case let fileURL as URL in enumerator {
                        let fileName = fileURL.lastPathComponent
                        if fileName.localizedCaseInsensitiveContains(query) {
                            let item = FileSystemItem(url: fileURL)
                            results.append(item)
                        }
                    }
                }
                
                continuation.resume(returning: results)
            }
        }
    }
}