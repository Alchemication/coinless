import Foundation

/// What MAME knows about a system, from `mame <id> -listxml`. Used by `./play --inspect` and `--check`.
struct MachineInfo: Sendable {
    let id: String
    let description: String
    let year: String
    let manufacturer: String
    let cloneOf: String?
    let players: Int?
    let buttons: Int?
    /// Driver emulation status: good, imperfect or preliminary.
    let status: String?
    let saveStates: Bool
    /// ZIPs MAME needs besides the game's own: its BIOS (`romof`, for a parent set) and devices with ROMs.
    /// Optional plug-in boards (slot options) aren't included; they don't need files to run.
    let requires: [String]

    /// The description without its region or version note: "Final Fight (World, set 1)" → "Final Fight".
    var title: String {
        description.replacingOccurrences(of: #"\s*\(.*\)\s*$"#, with: "", options: .regularExpression)
    }

    /// A folder name for games/: "Final Fight" → "final-fight".
    var folder: String {
        let slug = title.lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
        return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    static func load(_ id: String, mame: URL) -> MachineInfo? {
        guard let output = run(mame, [id, "-listxml"]), let document = try? XMLDocument(data: output),
              let machines = try? document.nodes(forXPath: "/mame/machine") as? [XMLElement],
              let machine = machines.first(where: { $0.value("name") == id }) else { return nil }

        let withROMs = Set(machines.filter { candidate in
            candidate.elements(forName: "rom").contains { $0.value("status") != "nodump" }
        }.compactMap { $0.value("name") })
        var requires: [String] = []
        if let bios = machine.value("romof"), bios != machine.value("cloneof") { requires.append(bios) }
        for reference in machine.elements(forName: "device_ref") {
            if let name = reference.value("name"), withROMs.contains(name), !requires.contains(name) { requires.append(name) }
        }

        let input = machine.elements(forName: "input").first
        let buttons = input?.elements(forName: "control").compactMap { $0.value("buttons").flatMap(Int.init) }.max()
        let driver = machine.elements(forName: "driver").first
        return MachineInfo(id: id,
                           description: machine.elements(forName: "description").first?.stringValue ?? id,
                           year: machine.elements(forName: "year").first?.stringValue ?? "?",
                           manufacturer: machine.elements(forName: "manufacturer").first?.stringValue ?? "?",
                           cloneOf: machine.value("cloneof"),
                           players: input?.value("players").flatMap(Int.init),
                           buttons: buttons,
                           status: driver?.value("status"),
                           saveStates: driver?.value("savestate") == "supported",
                           requires: requires)
    }

    /// Parent sets whose short name or description contains the query.
    static func search(_ query: String, mame: URL) -> [(id: String, description: String)] {
        guard let full = run(mame, ["-listfull"]).flatMap({ String(data: $0, encoding: .utf8) }) else { return [] }
        let clones = Set((run(mame, ["-listclones"]).flatMap { String(data: $0, encoding: .utf8) } ?? "")
            .split(separator: "\n").compactMap { $0.split(separator: " ").first.map(String.init) })
        let needle = query.lowercased()
        return full.split(separator: "\n").dropFirst().compactMap { line -> (String, String)? in
            guard let space = line.firstIndex(of: " ") else { return nil }
            let id = String(line[..<space])
            let description = line[space...].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard !clones.contains(id), id.contains(needle) || description.lowercased().contains(needle) else { return nil }
            return (id, description)
        }
    }

    /// A games.json entry to start from. Fields MAME can't know are marked TODO.
    var catalogDraft: String {
        let playerText = players.map { $0 == 1 ? "1 player" : "1–\($0) players" } ?? "TODO"
        var lines = [
            #"  "id": "\#(id)","#,
            #"  "folder": "\#(folder)","#,
            #"  "title": "\#(title)","#,
            #"  "subtitle": "TODO: a short, warm tagline","#,
            #"  "genre": "TODO: e.g. CO-OP BEAT ’EM UP","#,
            #"  "year": "\#(year)","#,
            #"  "players": "\#(playerText)","#,
            #"  "symbol": "TODO: an SF Symbol name","#,
            #"  "color": "TODO: hex accent, e.g. B8EA78","#,
            #"  "note": "TODO: one line on how to play","#,
            #"  "saveStates": \#(saveStates)"#,
        ]
        if !requires.isEmpty {
            lines[lines.count - 1] += ","
            lines.append(#"  "requires": [\#(requires.map { "\"\($0)\"" }.joined(separator: ", "))]"#)
        }
        return "{\n" + lines.joined(separator: "\n") + "\n}"
    }

    /// Whether a cartridge ZIP matches MAME's software list for its console (`-verifysoftware`).
    static func verifyCartridge(_ id: String, system: String, rompath: String, mame: URL) -> Bool {
        var arguments = [system, "-verifysoftware", "-rompath", rompath]
        if let hash = Library.hashFolder(for: mame) { arguments += ["-hashpath", hash.path] }
        guard let output = run(mame, arguments).flatMap({ String(data: $0, encoding: .utf8) }) else { return false }
        return output.contains("romset \(system):\(id) is good")
    }

    private static func run(_ mame: URL, _ arguments: [String]) -> Data? {
        let task = Process()
        task.executableURL = mame
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return task.terminationStatus == 0 ? data : nil
    }
}

private extension XMLElement {
    func value(_ attribute: String) -> String? { self.attribute(forName: attribute)?.stringValue }
}
