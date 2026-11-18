import SwiftUI

/// Starting and ending a game: MAME's command line from Library, a quit request that
/// launcher/quit.lua answers (so the automatic save is written), and the way back to
/// the library. State lives in ArcadeModel.
extension ArcadeModel {
    /// First press asks for confirmation; the second starts from the beginning.
    func newGame() {
        guard running == nil, !help, notice == nil, let game = active, resumeAvailable else { return }
        if confirmingFresh == game.id {
            confirmingFresh = nil
            launch(fresh: true)
            return
        }
        sounds.play(.warn)
        withAnimation(.easeOut(duration: 0.2)) { confirmingFresh = game.id }
        confirmTask?.cancel()
        confirmTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { self?.confirmingFresh = nil }
        }
    }

    func launch(fresh: Bool = false) {
        guard process == nil, let game = active, let library else { return }
        guard let mame = Library.mameURL() else {
            notice = Notice(title: "MAME isn't installed", message: "Install it with Homebrew (brew install mame), then try again. Coinless looks in /opt/homebrew/bin, /usr/local/bin and /opt/local/bin.")
            return
        }
        guard library.isInstalled(game) else {
            refresh()
            notice = Notice(title: "\(game.title) is missing", message: "Its ZIP was moved or removed. Check games/\(game.folder)/, then refresh.")
            return
        }
        let missing = library.missingFiles(game)
        guard missing.isEmpty else {
            let names = missing.map { $0 + ".zip" }.formatted(.list(type: .and))
            notice = Notice(title: "\(game.title) needs more files", message: "Add \(names) to games/\(game.folder)/ or the shared games/bios/ folder, then try again.")
            return
        }
        let mode: LaunchMode = Self.isSmokeTest || !autoResume ? .noSave : fresh ? .fresh : .resume
        stopPreviews()
        confirmingFresh = nil
        do {
            if mode == .fresh { try library.setAsideAutosave(game) }
            var arguments = library.arguments(game, fullscreen: fullscreen, mode: mode, style: displayStyle, mame: mame)
            let sandbox: URL? = Self.isSmokeTest ? FileManager.default.temporaryDirectory.appendingPathComponent("coinless-smoke-" + UUID().uuidString, isDirectory: true) : nil
            if let sandbox {
                try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
                arguments += ["-seconds_to_run", "30", "-nothrottle", "-video", "none", "-sound", "none",
                              "-cfg_directory", sandbox.path, "-nvram_directory", sandbox.path,
                              "-state_directory", sandbox.path, "-snapshot_directory", sandbox.path]
            }
            let logURL = sandbox?.appendingPathComponent("mame.log") ?? library.logFile
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            let output = try FileHandle(forWritingTo: logURL)

            let task = Process()
            task.executableURL = mame
            task.currentDirectoryURL = library.root
            task.arguments = arguments
            let request = FileManager.default.temporaryDirectory.appendingPathComponent("coinless-quit-" + UUID().uuidString)
            task.environment = ProcessInfo.processInfo.environment.merging(["COINLESS_QUIT_FILE": request.path]) { $1 }
            quitRequest = request
            task.standardInput = FileHandle.nullDevice
            task.standardOutput = output
            task.standardError = output
            let started = Date()
            task.terminationHandler = { [weak self] finished in
                let status = finished.terminationStatus
                let reason = finished.terminationReason
                let duration = Date().timeIntervalSince(started)
                Task { @MainActor in
                    self?.gameEnded(game, status: status, reason: reason, duration: duration, log: logURL, sandbox: sandbox)
                }
            }
            try task.run()
            mameLog = output
            process = task
            playingTip = facts[game.id]?.facts.filter(\.kind.isAdvice).randomElement()
            sounds.play(.start)
            withAnimation(.easeInOut(duration: 0.3)) { running = game }
            gameActivity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Listening for Options + Share during a game")
            updateBed()
            if !Self.isSmokeTest { Preferences.lastGame = game.id }
            // The smoke test leaves the way Options + Share does: through the quit request.
            if Self.isSmokeTest { Task { try? await Task.sleep(for: .seconds(4)); self.requestQuit() } }
        } catch {
            try? mameLog?.close()
            mameLog = nil
            process = nil
            running = nil
            notice = Notice(title: "Couldn't start \(game.title)", message: error.localizedDescription)
        }
    }

    /// Ends the running game like Esc does, so MAME still writes auto.sta, and the usual return to
    /// the library follows: launcher/quit.lua sees the request file and quits. If MAME hasn't gone
    /// a few seconds later (a warning screen, say), SIGTERM as well, which it sometimes honours.
    func requestQuit() {
        guard let process, process.isRunning, let quitRequest else { return }
        Self.padLog.notice("Asking MAME to quit")
        FileManager.default.createFile(atPath: quitRequest.path, contents: nil)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, self.process === process, process.isRunning else { return }
            Self.padLog.notice("MAME is still running 4 s after the quit request; sending SIGTERM too")
            process.terminate()
        }
    }

    func stopGame(then completion: @escaping () -> Void) {
        guard process != nil else { completion(); return }
        quitAfterGame = completion
        requestQuit()
    }

    private func gameEnded(_ game: Game, status: Int32, reason: Process.TerminationReason, duration: TimeInterval, log logURL: URL, sandbox: URL?) {
        try? mameLog?.close()
        mameLog = nil
        process = nil
        if let gameActivity { ProcessInfo.processInfo.endActivity(gameActivity) }
        gameActivity = nil
        if let quitRequest { try? FileManager.default.removeItem(at: quitRequest) }
        quitRequest = nil
        withAnimation(.easeInOut(duration: 0.3)) { running = nil }
        if let quitAfterGame {
            self.quitAfterGame = nil
            quitAfterGame()
            return
        }
        // The smoke test asks MAME to quit after 4 s; running on to -seconds_to_run means it didn't listen.
        let failed = status != 0 || reason == .uncaughtSignal || (sandbox != nil && duration > 20)
        if failed {
            let output = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            let tail = output.split(separator: "\n").suffix(10).joined(separator: "\n")
            notice = Notice(title: duration < 5 ? "Couldn't start \(game.title)" : "\(game.title) closed unexpectedly",
                            message: Library.exitSummary(status: status, reason: reason)
                                + (tail.isEmpty ? "" : "\n\n" + tail)
                                + "\n\nFull output: launcher/.build/mame-last.log")
        }
        if let sandbox {
            try? FileManager.default.removeItem(at: sandbox)
            print("Launch and return check: \(failed ? "failed" : "passed") (MAME status \(status))")
            if failed { print(notice?.message ?? "Unknown launch error") }
            exit(failed ? 1 : 0)
        }
        refreshSaves()
        reloadArtwork(game)
        if !failed { sounds.play(.welcome) }
        updateBed()
        // macOS may not give focus back right away; accept controller input for a while regardless.
        returnDeadline = Date().addingTimeInterval(20)
        onReturn?()
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            if !NSApp.isActive { self?.onReturn?() }
        }
        updatePreviews()
    }
}
