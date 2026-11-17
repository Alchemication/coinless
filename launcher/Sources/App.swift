import SwiftUI
import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = ArcadeModel()
    private var window: NSWindow?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // MAME opens full screen on the main display, so keep the library there too.
        let screen = NSScreen.screens.first ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 820)
        let size = NSSize(width: min(1280, visible.width), height: min(820, visible.height))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                               width: size.width, height: size.height), display: false)
        window.title = "Coinless"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 900, height: 660)
        window.backgroundColor = NSColor(Theme.background)
        window.contentView = NSHostingView(rootView: ArcadeView(model: model).preferredColorScheme(.dark))
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenPrimary]
        self.window = window
        model.onReturn = { [weak self] in self?.bringForward() }
        installMenu()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { [weak self] event in
            guard let self else { return event }
            let handled = event.type == .keyDown ? self.model.handleKey(event) : self.model.handleScroll(event)
            return handled ? nil : event
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()

        if ArcadeModel.isSmokeTest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.model.selection = self.model.games.firstIndex(where: { $0.id == "dino" }) ?? 0
                self.model.launch()
                if self.model.running == nil { print(self.model.notice?.message ?? "Smoke launch failed"); exit(1) }
            }
        } else if ArcadeModel.isPreview {
            if let id = CommandLine.arguments.drop(while: { $0 != "--preview" }).dropFirst().first,
               let index = model.games.firstIndex(where: { $0.id == id }) {
                model.selection = index
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.savePreview(of: window) }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { window.toggleFullScreen(nil) }
        }
    }

    func bringForward() {
        guard let window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.isPlaying else { return .terminateNow }
        // Let MAME exit cleanly first so it writes its automatic save.
        model.stopGame { NSApp.reply(toApplicationShouldTerminate: true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) { model.stopPreviews() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !model.isPlaying }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        bringForward()
        return true
    }

    @objc private func showSettings() { model.help = true }
    @objc private func refreshLibrary() { model.refresh() }

    private func installMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(item("Settings…", #selector(showSettings), ","))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Coinless", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let viewItem = NSMenuItem()
        menu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        viewItem.submenu = viewMenu
        viewMenu.addItem(item("Refresh Library", #selector(refreshLibrary), "r"))
        let fullScreen = NSMenuItem(title: "Toggle Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(fullScreen)
        NSApp.mainMenu = menu
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    /// `--preview [game]`: renders the window to launcher/.build/preview.png and quits.
    private func savePreview(of window: NSWindow) {
        // ImageRenderer draws blurs and effects that NSView.cacheDisplay leaves out.
        let size = window.contentView?.bounds.size ?? NSSize(width: 1280, height: 820)
        let renderer = ImageRenderer(content: ArcadeView(model: model).preferredColorScheme(.dark).frame(width: size.width, height: size.height))
        renderer.scale = window.backingScaleFactor
        guard let image = renderer.cgImage else { exit(1) }
        let bitmap = NSBitmapImageRep(cgImage: image)
        if let data = bitmap.representation(using: .png, properties: [:]), let root = model.library?.root {
            let file = root.appendingPathComponent("launcher/.build/preview.png")
            do { try data.write(to: file); print("Preview: \(file.path)") } catch { print(error); exit(1) }
        }
        NSApp.terminate(nil)
    }
}

@main struct Main {
    @MainActor static func main() {
        Preferences.migrateFromArcade()
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let command = arguments.first, CLI.commands.contains(command) {
            exit(CLI.run(arguments))
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
