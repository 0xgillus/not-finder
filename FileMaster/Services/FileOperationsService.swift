import Foundation
import Combine

@MainActor
class FileOperationsService: ObservableObject {
    @Published var isOperationInProgress = false
    @Published var operationProgress: Double = 0.0
    @Published var currentOperation: String = ""
    @Published var errorMessage: String?
    
    private let fileSystemService = FileSystemService()
    
    func createFolder(named name: String, in parentURL: URL) async throws {
        isOperationInProgress = true
        currentOperation = "Creating folder..."
        
        defer {
            isOperationInProgress = false
            currentOperation = ""
        }
        
        let newFolderURL = parentURL.appendingPathComponent(name)
        try await fileSystemService.createDirectory(at: newFolderURL)
    }
    
    func createFile(named name: String, in parentURL: URL) async throws {
        isOperationInProgress = true
        currentOperation = "Creating file..."
        
        defer {
            isOperationInProgress = false
            currentOperation = ""
        }
        
        let newFileURL = parentURL.appendingPathComponent(name)
        try await fileSystemService.createFile(at: newFileURL)
    }
    
    func rename(item: FileSystemItem, to newName: String) async throws {
        isOperationInProgress = true
        currentOperation = "Renaming..."
        
        defer {
            isOperationInProgress = false
            currentOperation = ""
        }
        
        try await fileSystemService.renameItem(at: item.url, to: newName)
    }
    
    func delete(items: [FileSystemItem]) async throws {
        isOperationInProgress = true
        operationProgress = 0.0
        
        defer {
            isOperationInProgress = false
            operationProgress = 0.0
            currentOperation = ""
        }
        
        let totalItems = items.count
        
        for (index, item) in items.enumerated() {
            currentOperation = "Deleting \(item.name)..."
            operationProgress = Double(index) / Double(totalItems)
            
            try await fileSystemService.deleteItem(at: item.url)
        }
        
        operationProgress = 1.0
    }
    
    func copy(items: [FileSystemItem], to destinationURL: URL) async throws {
        isOperationInProgress = true
        operationProgress = 0.0
        
        defer {
            isOperationInProgress = false
            operationProgress = 0.0
            currentOperation = ""
        }
        
        let totalItems = items.count
        
        for (index, item) in items.enumerated() {
            currentOperation = "Copying \(item.name)..."
            operationProgress = Double(index) / Double(totalItems)
            
            let destinationItemURL = destinationURL.appendingPathComponent(item.name)
            let finalDestinationURL = try await getUniqueDestinationURL(destinationItemURL)
            
            try await fileSystemService.copyItem(from: item.url, to: finalDestinationURL)
        }
        
        operationProgress = 1.0
    }
    
    func move(items: [FileSystemItem], to destinationURL: URL) async throws {
        isOperationInProgress = true
        operationProgress = 0.0
        
        defer {
            isOperationInProgress = false
            operationProgress = 0.0
            currentOperation = ""
        }
        
        let totalItems = items.count
        
        for (index, item) in items.enumerated() {
            currentOperation = "Moving \(item.name)..."
            operationProgress = Double(index) / Double(totalItems)
            
            let destinationItemURL = destinationURL.appendingPathComponent(item.name)
            let finalDestinationURL = try await getUniqueDestinationURL(destinationItemURL)
            
            try await fileSystemService.moveItem(from: item.url, to: finalDestinationURL)
        }
        
        operationProgress = 1.0
    }
    
    func paste(from clipboardManager: ClipboardManager, to destinationURL: URL) async throws {
        guard clipboardManager.hasItems else { return }
        
        switch clipboardManager.clipboardOperation {
        case .copy:
            try await copy(items: clipboardManager.clipboardItems, to: destinationURL)
        case .cut:
            try await move(items: clipboardManager.clipboardItems, to: destinationURL)
            clipboardManager.clear()
        }
    }
    
    private func getUniqueDestinationURL(_ url: URL) async throws -> URL {
        var destinationURL = url
        var counter = 1
        let fileManager = FileManager.default
        
        while fileManager.fileExists(atPath: destinationURL.path) {
            let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
            let pathExtension = url.pathExtension
            
            let newName: String
            if pathExtension.isEmpty {
                newName = "\(nameWithoutExtension) \(counter)"
            } else {
                newName = "\(nameWithoutExtension) \(counter).\(pathExtension)"
            }
            
            destinationURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            counter += 1
        }
        
        return destinationURL
    }
    
    func moveToTrash(items: [FileSystemItem]) async throws {
        isOperationInProgress = true
        operationProgress = 0.0
        
        defer {
            isOperationInProgress = false
            operationProgress = 0.0
            currentOperation = ""
        }
        
        let totalItems = items.count
        
        for (index, item) in items.enumerated() {
            currentOperation = "Moving \(item.name) to trash..."
            operationProgress = Double(index) / Double(totalItems)
            
            try await withCheckedThrowingContinuation { continuation in
                var resultingURL: NSURL?
                
                do {
                    try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultingURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        operationProgress = 1.0
    }
}

import SwiftUI

struct OperationProgressView: View {
    @ObservedObject var operationsService: FileOperationsService
    
    var body: some View {
        if operationsService.isOperationInProgress {
            VStack(spacing: 8) {
                HStack {
                    ProgressView(value: operationsService.operationProgress)
                        .frame(width: 200)
                    
                    Text("\(Int(operationsService.operationProgress * 100))%")
                        .font(.caption)
                        .frame(width: 30)
                }
                
                Text(operationsService.currentOperation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .shadow(radius: 4)
        }
    }
}