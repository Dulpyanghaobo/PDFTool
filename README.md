# PDFTool

A Swift package providing PDF manipulation utilities for iOS/macOS applications.

## Overview

PDFTool is a modular PDF toolkit that provides:

- **PDFTool** - Core PDF operations (rendering, page manipulation, export)
- **PDFToolRepository** - File system repository types and protocols

## Requirements

- iOS 18.0+ / macOS 13.0+
- Swift 6.0+

## Installation

### Swift Package Manager

Add PDFTool to your project via Xcode:

1. File > Add Package Dependencies
2. Select "Add Local..." and navigate to the PDFTool directory
3. Select the products you need:
   - `PDFTool` - Core PDF operations
   - `PDFToolRepository` - Repository types and protocols

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../PDFTool")
]
```

## Modules

### PDFTool (Core)

Core PDF manipulation utilities:

```swift
import PDFTool

// Document management
let doc = try PDFDocumentManager.shared.openDocument(at: url)

// Page operations
try PDFPageOperations.shared.insertImagesAndSave(images, into: pdfURL, at: 0)
try PDFPageOperations.shared.deletePagesAndSave(at: [0, 1], from: pdfURL)
try PDFPageOperations.shared.rotatePagesAndSave(at: [0], by: 1, in: pdfURL)

// Rendering
let image = PDFRenderer.shared.renderPage(from: url, pageIndex: 0, maxLongSide: 2000)

// Export
let data = try PDFExporter.shared.exportToData(pages: exportablePages)

// Page size export
try PDFPageSizeExporter.shared.export(
    inputURL: inputURL,
    outputURL: outputURL,
    pageSizes: [0: .a4, 1: .usLetter]
)
```

### PDFToolRepository

File system repository types and protocols for document management:

```swift
import PDFToolRepository

// Types
let item = FileItem(
    id: UUID(),
    kind: .document,
    name: "My Document",
    pageCount: 5,
    contentKind: .pdf
)

let pageSize = PageSize.a4
print(pageSize.physical) // CGSize(210, 297) mm
print(pageSize.points)   // CGSize in points

let error = FileSystemError.notFound(UUID())

// Edit operations
let op = EditOp.rotate90CW(pageIndex: 0)
let filterOp = EditOp.applyFilter(filter: .gray, pageIndex: 0)

// File system monitor
let monitor = SDMonitor()
for await event in monitor.events {
    switch event {
    case .added(let item): print("Added: \(item.name)")
    case .removed(let id, _): print("Removed: \(id)")
    case .updated(let item): print("Updated: \(item.name)")
    case .moved(let id, _, _): print("Moved: \(id)")
    }
}

// Protocols
protocol MyStore: FileSystemStore {
    // Implement all required methods
}
```

## Module Contents

### PDFTool

| File | Description |
|------|-------------|
| `PDFTool.swift` | Main entry point |
| `Core/PDFToolTypes.swift` | Core type definitions |
| `Document/PDFDocumentManager.swift` | Document open/save operations |
| `Pages/PDFPageOperations.swift` | Page manipulation (insert, delete, rotate, etc.) |
| `Render/PDFRenderer.swift` | PDF rendering to images |
| `Export/PDFExporter.swift` | PDF export functionality |
| `PageSize/PDFPageSizeExporter.swift` | Page size transformation |

### PDFToolRepository

| File | Description |
|------|-------------|
| `PDFToolRepository.swift` | Main entry, SDMonitor implementation |
| `Core/RepositoryTypes.swift` | Basic enums (FileItemKind, ContentKind, PDFVariant, etc.) |
| `Model/FileItem.swift` | FileItem, PageItem, RevisionItem, NoteItem, SignatureItem |
| `Model/EditOp.swift` | EditOp, FilterType, Quad |
| `Model/PageSize.swift` | PageSize enum with physical dimensions |
| `Protocols/FileSystemStore.swift` | All protocol definitions |

## Architecture

```
PDFTool/
├── Sources/
│   ├── PDFTool/                    # Core PDF operations
│   │   ├── Core/
│   │   ├── Document/
│   │   ├── Pages/
│   │   ├── Render/
│   │   ├── Export/
│   │   └── PageSize/
│   │
│   └── PDFToolRepository/          # Repository types & protocols
│       ├── Core/
│       ├── Model/
│       └── Protocols/
│
└── Tests/
    ├── PDFToolTests/
    └── PDFToolRepositoryTests/
```

## Migration from DocumentScan Repo

If you're migrating from DocumentScan's inline Repo module to PDFToolRepository:

1. Add PDFToolRepository to your project
2. Import PDFToolRepository where needed
3. Use the bridge file (`PDFToolRepositoryBridge.swift`) for gradual migration
4. SwiftData entities (DocumentMO, FolderMO, etc.) remain in your app

See `DocumentScan/DocumentScan/App/PDFToolRepositoryBridge.swift` for detailed migration guide.

## License

MIT License