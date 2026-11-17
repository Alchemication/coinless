import SwiftUI
import AppKit
import GameController

struct Game: Codable, Identifiable {
    let id: String
    let folder: String
    let title: String
    let subtitle: String
    let genre: String
    let year: String
    let players: String
    let symbol: String
    let color: String
    let note: String
    let saveStates: Bool
    var tint: Color { Color(hex: color) }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0xB8EA78
        self.init(red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255)
    }
}

struct Library {
    let root: URL
    let catalog: [Game]
    init(bundle: Bundle = .main) throws {
        guard let catalogURL = bundle.url(forResource: "games", withExtension: "json"),
              let pathURL = bundle.url(forResource: "project-path", withExtension: "txt") else {
            throw NSError(domain: "Arcade", code: 1, userInfo: [NSLocalizedDescriptionKey: "The app is missing its library configuration. Run launcher/build.sh again."])
        }
        let path = try String(contentsOf: pathURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        root = URL(fileURLWithPath: path, isDirectory: true)
        catalog = try JSONDecoder().decode([Game].self, from: Data(contentsOf: catalogURL))
        let ids = catalog.map(\.id)
        guard Set(ids).count == ids.count, catalog.allSatisfy({ game in
            game.id.range(of: "^[a-z0-9_]+$", options: .regularExpression) != nil &&
            game.folder.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil
        }) else {
            throw NSError(domain: "Arcade", code: 2, userInfo: [NSLocalizedDescriptionKey: "The game catalog has duplicate names or invalid folder paths."])
        }
    }
    var games: [Game] {
        catalog.filter { FileManager.default.fileExists(atPath: romFolder($0).appendingPathComponent($0.id + ".zip").path) }
    }
    func romFolder(_ game: Game) -> URL { root.appendingPathComponent("games").appendingPathComponent(game.folder) }
    func resumeSlot(_ game: Game) -> String? {
        guard game.saveStates else { return nil }
        let directory = root.appendingPathComponent("sta").appendingPathComponent(game.id)
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent("auto.sta").path) { return "auto" }
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey])) ?? []
        return files.filter { $0.pathExtension == "sta" && ((try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true) }
            .max { a, b in
                let first = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let second = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return first < second
            }?.deletingPathExtension().lastPathComponent
    }
    func arguments(_ game: Game, fullscreen: Bool, autoResume: Bool = true) -> [String] {
        var arguments = [game.id, "-rompath", romFolder(game).path, fullscreen ? "-nowindow" : "-window",
                         "-video", "opengl", "-filter", "-keepaspect", "-joystick",
                         "-state_directory", root.appendingPathComponent("sta").path]
        let enabled = game.saveStates && autoResume
        arguments += [enabled ? "-autosave" : "-noautosave"]
        if enabled, let slot = resumeSlot(game), slot != "auto" { arguments += ["-state", slot] }
        return arguments
    }
    static func mameURL() -> URL? {
        var candidates = ["/opt/homebrew/bin/mame", "/usr/local/bin/mame", "/opt/local/bin/mame"]
        candidates += (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/mame" }
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }
}

@MainActor final class ArcadeModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var selection = 0
    @Published var running: Game?
    @Published var error: String?
    @Published var help = false
    @Published var controllerCount = 0
    @Published var fullscreen = UserDefaults.standard.object(forKey: "gameFullscreen") as? Bool ?? true {
        didSet { UserDefaults.standard.set(fullscreen, forKey: "gameFullscreen") }
    }
    @Published var autoResume = UserDefaults.standard.object(forKey: "autoResume") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoResume, forKey: "autoResume") }
    }
    let library: Library?
    private var process: Process?
    private var log: FileHandle?
    private var observers: [NSObjectProtocol] = []
    private var direction: [String: Int] = [:]
    var columns = 2
    var active: Game? { games.indices.contains(selection) ? games[selection] : nil }
    var resumeAvailable: Bool { autoResume && active.flatMap { library?.resumeSlot($0) } != nil }

    init() {
        do { library = try Library() } catch { library = nil; self.error = error.localizedDescription }
        refresh()
        observers.append(NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.configureControllers() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.configureControllers() }
        })
        configureControllers()
    }
    func refresh() {
        let previous = active?.id ?? UserDefaults.standard.string(forKey: "lastGame")
        games = library?.games ?? []
        selection = games.firstIndex(where: { $0.id == previous }) ?? min(selection, max(0, games.count - 1))
    }
    func move(_ delta: Int) {
        guard running == nil, !help, !games.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.15)) { selection = min(max(selection + delta, 0), games.count - 1) }
    }
    func launch() {
        guard process == nil, let game = active, let library else { return }
        guard let executable = Library.mameURL() else {
            error = "MAME was not found. Install it with Homebrew, or make sure its executable is in /opt/homebrew/bin, /usr/local/bin, or /opt/local/bin."
            return
        }
        guard FileManager.default.fileExists(atPath: library.romFolder(game).appendingPathComponent(game.id + ".zip").path) else {
            refresh(); error = "This game's ZIP was moved or removed. Check its folder and refresh the library."; return
        }
        do {
            let logs = library.root.appendingPathComponent("launcher/.build", isDirectory: true)
            try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
            let logURL = logs.appendingPathComponent("mame-last.log")
            try Data().write(to: logURL)
            let output = try FileHandle(forWritingTo: logURL)
            let task = Process()
            task.executableURL = executable
            task.currentDirectoryURL = library.root
            var arguments = library.arguments(game, fullscreen: fullscreen, autoResume: autoResume)
            if CommandLine.arguments.contains("--smoke-test") {
                let isolated = FileManager.default.temporaryDirectory.appendingPathComponent("arcade-smoke-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: isolated, withIntermediateDirectories: true)
                arguments = library.arguments(game, fullscreen: fullscreen, autoResume: false)
                arguments += ["-seconds_to_run", "2", "-nothrottle", "-skip_gameinfo", "-video", "none", "-sound", "none",
                              "-cfg_directory", isolated.path, "-nvram_directory", isolated.path,
                              "-state_directory", isolated.path, "-snapshot_directory", isolated.path]
            }
            task.arguments = arguments
            task.standardInput = FileHandle.nullDevice
            task.standardOutput = output
            task.standardError = output
            task.terminationHandler = { [weak self] finished in
                let status = finished.terminationStatus
                Task { @MainActor in
                    guard let self else { return }
                    try? self.log?.close()
                    self.log = nil
                    self.process = nil
                    self.running = nil
                    if status != 0 {
                        let message = (try? String(contentsOf: logURL, encoding: .utf8)) ?? "No error output was available."
                        self.error = "MAME exited with code \(status).\n\n" + String(message.suffix(2800))
                    }
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    if CommandLine.arguments.contains("--smoke-test") {
                        print("Launch and return check: \(status == 0 ? "passed" : "failed") (MAME status \(status))")
                        if status != 0 { print(self.error ?? "Unknown launch error") }
                        exit(status == 0 ? 0 : 1)
                    }
                }
            }
            log = output
            process = task
            running = game
            try task.run()
            if !CommandLine.arguments.contains("--smoke-test") {
                UserDefaults.standard.set(game.id, forKey: "lastGame")
            }
        } catch {
            try? log?.close(); log = nil; process = nil; running = nil
            self.error = "Couldn't start MAME: \(error.localizedDescription)"
        }
    }
    private var acceptsController: Bool { NSApp.isActive && running == nil }
    private func route(x: Float, y: Float, token: String) {
        guard acceptsController else { direction[token] = 0; return }
        let next: Int = abs(x) > abs(y) ? (x > 0.5 ? 1 : x < -0.5 ? -1 : 0) : (y > 0.5 ? -columns : y < -0.5 ? columns : 0)
        if next != 0 && direction[token] != next { move(next) }
        direction[token] = next
    }
    func configureControllers() {
        controllerCount = GCController.controllers().count
        for controller in GCController.controllers() {
            guard let pad = controller.extendedGamepad else { continue }
            let token = String(describing: ObjectIdentifier(controller))
            pad.dpad.valueChangedHandler = { [weak self] _, x, y in Task { @MainActor in self?.route(x: x, y: y, token: token + "d") } }
            pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in Task { @MainActor in self?.route(x: x, y: y, token: token + "s") } }
            pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor in
                    guard let self, self.acceptsController else { return }
                    if self.help { self.help = false } else if self.error != nil { self.error = nil } else { self.launch() }
                }
            }
            pad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor in
                    guard let self, self.acceptsController else { return }
                    if self.error != nil { self.error = nil } else { self.help.toggle() }
                }
            }
            pad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { Task { @MainActor in guard let self, self.acceptsController else { return }; self.refresh() } }
            }
            pad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { Task { @MainActor in guard let self, self.acceptsController else { return }; self.help.toggle() } }
            }
        }
    }
}

struct Tile: View {
    let game: Game
    let selected: Bool
    let index: Int
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 23).fill(LinearGradient(colors: [game.tint.opacity(0.27), Color(hex: "191D23"), Color(hex: "14171D")], startPoint: .topTrailing, endPoint: .bottomLeading))
            GeometryReader { geo in
                Path { p in
                    for offset in stride(from: -200, through: 800, by: 50) {
                        p.move(to: CGPoint(x: CGFloat(offset), y: 0))
                        p.addLine(to: CGPoint(x: CGFloat(offset) + 230, y: geo.size.height))
                    }
                }.stroke(game.tint.opacity(0.055), lineWidth: 15)
            }.clipped()
            Image(systemName: game.symbol).font(.system(size: 112, weight: .light)).foregroundStyle(game.tint.opacity(selected ? 0.48 : 0.22)).rotationEffect(.degrees(-12)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(25)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(String(format: "%02d", index + 1)).font(.system(size: 13, weight: .semibold, design: .monospaced))
                    Spacer()
                    if selected { Label("SELECTED", systemImage: "circle.fill").font(.system(size: 10, weight: .bold, design: .monospaced)) }
                }.foregroundStyle(game.tint)
                Spacer(minLength: 0)
                Text(game.genre).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(game.tint)
                Text(game.title).font(.system(size: 29, weight: .heavy, design: .rounded)).lineLimit(2).minimumScaleFactor(0.7).foregroundStyle(.white)
                HStack {
                    Text(game.year + "   /   " + game.players).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Image(systemName: selected ? "arrow.up.right.circle.fill" : "arrow.up.right").font(.system(size: 24)).foregroundStyle(selected ? game.tint : .white.opacity(0.25))
                }
            }.padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 23))
        .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(selected ? game.tint : .white.opacity(0.08), lineWidth: selected ? 2.5 : 1))
        .shadow(color: game.tint.opacity(selected ? 0.13 : 0), radius: 20, y: 8)
        .scaleEffect(selected ? 1 : 0.98)
        .accessibilityLabel(game.title + ", " + game.players)
    }
}

struct ArcadeView: View {
    @ObservedObject var model: ArcadeModel
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 1000
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 11) {
                        Image(systemName: "arcade.stick.console.fill").font(.system(size: 25)).foregroundStyle(Color(hex: "B8EA78"))
                        Text("ARCADE").font(.system(size: 18, weight: .black, design: .monospaced)).tracking(4)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Circle().fill(model.controllerCount > 0 ? Color(hex: "B8EA78") : .gray).frame(width: 6, height: 6)
                        Text(model.controllerCount > 0 ? "\(model.controllerCount) CONTROLLER\(model.controllerCount == 1 ? "" : "S") CONNECTED" : "KEYBOARD READY")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1)
                    }.foregroundStyle(.white.opacity(0.65))
                    Button { model.help.toggle() } label: { Image(systemName: "questionmark.circle").font(.system(size: 21)) }.buttonStyle(.plain).padding(.leading, 18).help("Controls and settings")
                }.padding(.bottom, 28)
                HStack(alignment: .firstTextBaseline) {
                    Text("Good times.\nOne more game.").font(.system(size: compact ? 37 : 49, weight: .bold, design: .rounded)).tracking(-1.8).lineSpacing(-4)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("YOUR COLLECTION").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(Color(hex: "B8EA78"))
                        Text("\(model.games.count) games · no coins required").font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
                    }
                }.padding(.bottom, 25)
                if model.games.isEmpty {
                    ContentUnavailableView("Your arcade is waiting", systemImage: "gamecontroller", description: Text("Add game ZIPs to the folders listed in README.md, then refresh with R or △ / Y."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), spacing: 14) {
                                ForEach(Array(model.games.enumerated()), id: \.element.id) { index, game in
                                    Button {
                                        model.selection = index
                                        model.launch()
                                    } label: { Tile(game: game, selected: model.selection == index, index: index).frame(height: max(145, min(260, (geometry.size.height - 440) / 2))) }
                                    .buttonStyle(.plain).id(index)
                                    .help("Play \(game.title)")
                                }
                            }.padding(5)
                        }.scrollIndicators(.hidden)
                            .onChange(of: model.selection) { _, next in withAnimation { proxy.scrollTo(next, anchor: .center) } }
                    }
                }
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.active?.subtitle ?? "Your own little arcade.").font(.system(size: 14, weight: .semibold))
                        Text(model.resumeAvailable ? "Continue your saved session. Quit normally to save again." : model.active?.note ?? "Select a game to get started.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45)).lineLimit(2)
                    }
                    Spacer(minLength: 10)
                    Button { model.launch() } label: {
                        HStack(spacing: 12) { Image(systemName: model.resumeAvailable ? "arrow.clockwise" : "play.fill"); Text(model.resumeAvailable ? "RESUME" : "PLAY").tracking(2) }
                            .font(.system(size: 13, weight: .black)).padding(.horizontal, 28).padding(.vertical, 16)
                            .foregroundStyle(Color(hex: "111510")).background(model.active?.tint ?? Color.gray, in: Capsule())
                    }.buttonStyle(.plain).disabled(model.active == nil)
                }.padding(.top, 21)
                HStack(spacing: 24) {
                    Text("D-PAD / ARROWS   Move")
                    Text("✕ / RETURN   Play")
                    Text("OPTIONS / ○ / ?   Help")
                    Spacer()
                    Text("Made for your couch.").foregroundStyle(.white.opacity(0.25))
                }.font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.45)).padding(.top, 25)
            }.padding(compact ? 30 : 44)
        }
        .foregroundStyle(.white).background(Color(hex: "101216"))
        .overlay {
            if let game = model.running {
                ZStack {
                    Color(hex: "101216").opacity(0.98)
                    VStack(spacing: 20) {
                        Image(systemName: game.symbol).font(.system(size: 70)).foregroundStyle(game.tint)
                        Text("Enjoy the game.").font(.system(size: 40, weight: .bold, design: .rounded))
                        Text(game.title).font(.title3).foregroundStyle(.secondary)
                        Text("Quit MAME to return to your collection.\nUse Esc, or the controller button you assigned to UI Cancel.")
                            .multilineTextAlignment(.center).font(.system(size: 14)).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .sheet(isPresented: $model.help) { helpView }
        .alert("Couldn't start the game", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var helpView: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            HStack { Text("Settle in. Play.").font(.system(size: 30, weight: .bold, design: .rounded)); Spacer(); Button("Done") { model.help = false }.keyboardShortcut(.cancelAction) }
            Text("Browse with your PS4 controller’s D-pad or left stick, or use the arrow keys. Press ✕ or Return to play. With a mouse, click any game tile to launch it.").foregroundStyle(.secondary)
            Divider()
            Text("Back to the collection").font(.headline)
            Text("Quit a game with Esc. For couch play, set a spare controller button to UI Cancel in MAME: Tab → Input Settings → Input Assignments (general) → User Interface. Choose a button you won't press during play. Your existing game controls stay in place.").foregroundStyle(.secondary)
            Toggle("Launch games in full screen", isOn: $model.fullscreen)
            Toggle("Automatically save on exit and resume next time", isOn: $model.autoResume)
            Text("Works with supported games, including Cadillacs, Heaven’s Gate, and SF2. On first use, resumes your latest manual save if there is no automatic save. Turn this off for a fresh session without automatic saving. Tekken 3 and Golden Axe always start normally.").font(.caption).foregroundStyle(.secondary)
            Text("Controller quick saves").font(.headline)
            Text("In MAME’s general input assignments → User Interface, bind Save State (Quick) to L3 and Load State (Quick) to R3 (click the sticks). These are separate from the regular Save/Load State actions that ask you to choose a slot. Use a combination if you tend to click the sticks by accident.").font(.callout).foregroundStyle(.secondary)
            Text("Your last played game and this preference are remembered. Either connected controller can browse the library. Press ○ or Options to close this panel.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Refresh games") { model.refresh() }
                Button("Open game folders") { if let root = model.library?.root { NSWorkspace.shared.open(root.appendingPathComponent("games")) } }
                Button("Read setup guide") { if let root = model.library?.root { NSWorkspace.shared.open(root.appendingPathComponent("README.md")) } }
            }
            Text("New downloads from the shortlist appear automatically. Other games can be added to launcher/games.json; rebuild the app afterward.").font(.caption).foregroundStyle(.secondary)
          }.padding(32)
        }.frame(width: 640, height: 640).preferredColorScheme(.dark)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = ArcadeModel()
    var window: NSWindow?
    var keyboardMonitor: Any?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let screen = NSScreen.screens.first(where: { $0 != NSScreen.screens.first }) ?? NSScreen.main
        let rect = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let window = NSWindow(contentRect: NSRect(x: rect.midX - 600, y: rect.midY - 400, width: min(1200, rect.width), height: min(800, rect.height)), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false, screen: screen)
        window.title = "Arcade"
        window.minSize = NSSize(width: 800, height: 650)
        window.backgroundColor = NSColor(Color(hex: "101216"))
        window.titlebarAppearsTransparent = true
        window.contentView = NSHostingView(rootView: ArcadeView(model: model).preferredColorScheme(.dark))
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenPrimary]
        self.window = window
        installMenu()
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.model.running == nil, !self.model.help, self.model.error == nil,
                  event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
            switch event.keyCode {
            case 123: self.model.move(-1)
            case 124: self.model.move(1)
            case 125: self.model.move(self.model.columns)
            case 126: self.model.move(-self.model.columns)
            case 36, 76: if !event.isARepeat { self.model.launch() }
            default:
                switch event.characters?.lowercased() {
                case "r": self.model.refresh()
                case "?": self.model.help = true
                default: return event
                }
            }
            return nil
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--smoke-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.model.selection = self.model.games.firstIndex(where: { $0.id == "dino" }) ?? 0
                self.model.launch()
                if self.model.running == nil { print(self.model.error ?? "Smoke launch failed"); exit(1) }
            }
        } else if CommandLine.arguments.contains("--preview") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                guard let view = window.contentView,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                if let data = bitmap.representation(using: .png, properties: [:]), let root = self.model.library?.root {
                    let file = root.appendingPathComponent("launcher/.build/preview.png")
                    do { try data.write(to: file); print("Preview: \(file.path)") } catch { print(error); exit(1) }
                }
                NSApp.terminate(nil)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { window.toggleFullScreen(nil) }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { model.running == nil }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { window?.makeKeyAndOrderFront(nil); return true }
    private func installMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit Arcade", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let viewItem = NSMenuItem(); menu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View"); viewItem.submenu = viewMenu
        let full = NSMenuItem(title: "Toggle Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        full.keyEquivalentModifierMask = [.command, .control]; viewMenu.addItem(full)
        NSApp.mainMenu = menu
    }
}

@main struct Main {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--check") {
            do {
                let library = try Library()
                guard FileManager.default.fileExists(atPath: library.root.appendingPathComponent("games").path) else { throw NSError(domain: "Arcade", code: 3, userInfo: [NSLocalizedDescriptionKey: "Project games folder not found."]) }
                let games = library.games
                guard !games.isEmpty else { throw NSError(domain: "Arcade", code: 4, userInfo: [NSLocalizedDescriptionKey: "No installed games found."]) }
                guard let mame = Library.mameURL() else { throw NSError(domain: "Arcade", code: 5, userInfo: [NSLocalizedDescriptionKey: "MAME executable not found."]) }
                for game in games {
                    let args = library.arguments(game, fullscreen: true)
                    guard args.first == game.id, args.contains("-nowindow"), args.contains(library.romFolder(game).path) else { fatalError("Invalid launch arguments") }
                    guard args.contains(game.saveStates ? "-autosave" : "-noautosave") else { fatalError("Incorrect autosave capability") }
                    guard library.arguments(game, fullscreen: true, autoResume: false).contains("-noautosave") else { fatalError("Fresh sessions must disable autosave") }
                    print("Ready: \(game.title) [\(game.id)] → \(library.romFolder(game).path)")
                }
                print("Library and launch checks passed. MAME: \(mame.path)")
            } catch { fputs("Arcade check failed: \(error.localizedDescription)\n", stderr); exit(1) }
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
