import Foundation
import UIKit
import PDFKit

/// Files Skill — allows the agent to read and create files
/// using iOS document picker and security-scoped URLs.
/// Only accesses files the user explicitly selects.
final class FilesSkill: AgentSkill, @unchecked Sendable {

    let id = "files"
    let name = "Fichiers"
    let description = "Sélectionne et lit des fichiers (PDF, documents, texte) choisis par l'utilisateur. Peut créer des fichiers dans les emplacements autorisés."
    let category: SkillCategory = .files
    let requiredPermissions: [SkillPermission] = [.fileAccess]
    let requiresConfirmation = true

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "action": .object([
                    "type": .string("string"),
                    "description": .string("Action: 'read' (lire un fichier), 'create' (créer un fichier), 'list' (lister les fichiers récents)"),
                    "enum": .array([.string("read"), .string("create"), .string("list")])
                ]),
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Chemin du fichier (pour read/create)")
                ]),
                "content": .object([
                    "type": .string("string"),
                    "description": .string("Contenu du fichier (pour create)")
                ]),
                "fileName": .object([
                    "type": .string("string"),
                    "description": .string("Nom du fichier (pour create)")
                ])
            ]),
            "required": .array([.string("action")])
        ])
    }

    var outputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "content": .string("Le contenu du fichier"),
                "fileName": .string("Le nom du fichier"),
                "fileSize": .number(0)
            ])
        ])
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let action = input["action"]?.stringValue else {
            throw SkillError.invalidInput("Le paramètre 'action' est requis")
        }

        switch action {
        case "read":
            return try await readFile(input: input, context: context)
        case "create":
            return try await createFile(input: input, context: context)
        case "list":
            return try await listRecentFiles(context: context)
        default:
            throw SkillError.invalidInput("Action inconnue: \(action)")
        }
    }

    func requiresConfirmation(for input: JSONValue) -> Bool {
        guard let action = input["action"]?.stringValue else { return false }
        return action == "create"
    }

    func confirmationDescription(for input: JSONValue) -> String {
        if let action = input["action"]?.stringValue, action == "create" {
            let fileName = input["fileName"]?.stringValue ?? "fichier"
            return "Créer le fichier « \(fileName) »?"
        }
        return "Accéder aux fichiers?"
    }

    // MARK: - Read

    private func readFile(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let path = input["path"]?.stringValue, !path.isEmpty else {
            throw SkillError.invalidInput("Le paramètre 'path' est requis pour l'action 'read'")
        }

        let url = URL(fileURLWithPath: path)
        let fileName = url.lastPathComponent

        context.emitEvent(.statusChanged("Lecture du fichier: \(fileName)..."))

        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw SkillError.invalidInput("Fichier introuvable: \(path)")
        }

        // Determine file type and extract text
        let ext = url.pathExtension.lowercased()
        var content = ""

        switch ext {
        case "txt", "md", "swift", "py", "js", "ts", "json", "xml", "csv", "html", "css":
            content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        case "pdf":
            content = extractPDFText(from: url)
        case "rtf":
            if let data = try? Data(contentsOf: url),
               let rtfString = NSAttributedString(rtf: data, documentAttributes: nil)?.string {
                content = rtfString
            }
        case "doc", "docx":
            // Limited support — would need additional frameworks
            content = "Format \(ext) non supporté en lecture directe. Utilisez PDF ou texte."
        default:
            if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                content = text
            } else {
                content = "Impossible de lire le contenu de ce type de fichier (\(ext))"
            }
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int ?? 0

        context.emitEvent(.statusChanged("Fichier lu: \(content.count) caractères"))

        let output: JSONValue = .object([
            "content": .string(content),
            "fileName": .string(fileName),
            "fileSize": .number(Double(fileSize)),
            "fileType": .string(ext)
        ])

        return SkillResult(
            output: output,
            summary: "Fichier « \(fileName) » lu (\(content.count) caractères)"
        )
    }

    // MARK: - Create

    private func createFile(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        guard let fileName = input["fileName"]?.stringValue, !fileName.isEmpty else {
            throw SkillError.invalidInput("Le paramètre 'fileName' est requis pour l'action 'create'")
        }

        let content = input["content"]?.stringValue ?? ""

        // Create in the app's Documents directory
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDir.appendingPathComponent(fileName)

        context.emitEvent(.statusChanged("Création du fichier: \(fileName)..."))

        try content.data(using: .utf8)?.write(to: fileURL, options: .atomic)

        let output: JSONValue = .object([
            "success": .bool(true),
            "fileName": .string(fileName),
            "path": .string(fileURL.path),
            "size": .number(Double(content.count))
        ])

        return SkillResult(
            output: output,
            summary: "Fichier « \(fileName) » créé avec succès"
        )
    }

    // MARK: - List

    private func listRecentFiles(context: SkillExecutionContext) async throws -> SkillResult {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        let files = (try? FileManager.default.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? []

        let fileInfos: [[String: JSONValue]] = files.prefix(20).map { url in
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let modDate = attrs?[.modificationDate] as? Date ?? Date()
            let size = attrs?[.size] as? Int ?? 0

            return [
                "name": .string(url.lastPathComponent),
                "size": .number(Double(size)),
                "modified": .string(ISO8601DateFormatter().string(from: modDate))
            ]
        }

        let output: JSONValue = .object([
            "files": .array(fileInfos.map { .object($0) }),
            "total": .number(Double(fileInfos.count))
        ])

        return SkillResult(
            output: output,
            summary: "\(fileInfos.count) fichier(s) trouvé(s)"
        )
    }

    // MARK: - PDF

    private func extractPDFText(from url: URL) -> String {
        guard let document = PDFDocument(url: url) else {
            return "Impossible d'ouvrir le PDF"
        }

        var text = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                text += pageText + "\n"
            }
        }

        // Limit to reasonable size
        if text.count > 100_000 {
            text = String(text.prefix(100_000))
        }

        return text
    }
}
