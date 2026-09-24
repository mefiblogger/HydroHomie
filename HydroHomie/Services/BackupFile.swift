// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UniformTypeIdentifiers

/// Wraps an encoded archive so `fileExporter` can write it out.
///
/// The bytes are encoded once, before the export sheet appears, so a failure is
/// reported while the user is still looking at Settings rather than after they have
/// chosen where to save.
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var suggestedFilename: String
    private var data: Data

    init(archive: BackupArchive, data: Data) {
        self.suggestedFilename = archive.suggestedFilename
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw BackupError.unreadable
        }
        data = contents
        suggestedFilename = configuration.file.filename ?? "HydroHomie-Backup.json"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// A one-off message shown after an export or import.
struct BackupMessage: Identifiable {
    let id = UUID()
    var text: String
}
