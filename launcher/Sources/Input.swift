import AppKit
import GameController

enum Direction: Equatable { case left, right, up, down }

private enum KeyCode {
    static let left: UInt16 = 123
    static let right: UInt16 = 124
    static let down: UInt16 = 125
    static let up: UInt16 = 126
    static let enter: UInt16 = 36
    static let keypadEnter: UInt16 = 76
}

/// Controller, keyboard and trackpad handling. All actions route through the same few verbs.
extension ArcadeModel {
    // MARK: Verbs

    func handle(_ direction: Direction) {
        guard running == nil, notice == nil else { return }
        if help {
            let items = HelpItem.allCases
            switch direction {
            case .up, .down:
                let target = items[min(max(helpFocus.rawValue + (direction == .up ? -1 : 1), 0), items.count - 1)]
                sounds.play(target == helpFocus ? .bump : .move)
                helpFocus = target
            case .left, .right:
                if helpFocus == .display { cycleDisplayStyle(direction == .right ? 1 : -1) }
                if helpFocus == .music && music { sounds.skip(direction == .right ? 1 : -1) }
            }
            return
        }
        switch direction {
        case .left: move(-1)
        case .right: move(1)
        case .up: stepFact(-1)
        case .down: stepFact(1)
        }
    }

    /// ✕ / Return.
    func confirm() {
        if notice != nil { notice = nil } else if help { activateHelpItem() } else { launch() }
    }

    /// ○: closes whatever is open, otherwise opens help.
    func back() {
        if notice != nil { notice = nil } else { help.toggle() }
    }

    func activateHelpItem() {
        switch helpFocus {
        case .quit: NSApp.terminate(nil); return
        case .fullscreen: fullscreen.toggle()
        case .autoResume: autoResume.toggle()
        case .display: cycleDisplayStyle(1)
        case .music: music.toggle()
        case .interfaceSounds: interfaceSounds.toggle()
        }
        sounds.play(.open)
    }

    func cycleDisplayStyle(_ step: Int) {
        let styles = DisplayStyle.allCases
        let index = styles.firstIndex(of: displayStyle) ?? 0
        displayStyle = styles[(index + step + styles.count) % styles.count]
    }

    // MARK: Controllers

    /// Input counts while the launcher is frontmost, or shortly after a game ends in case macOS
    /// didn't hand focus back. Otherwise background presses (e.g. while in Safari) are ignored.
    var acceptsController: Bool {
        guard running == nil else { return false }
        if NSApp.isActive { returnDeadline = nil; return true }
        return returnDeadline.map { Date() < $0 } ?? false
    }

    private func claimController() -> Bool {
        guard acceptsController else { return false }
        if !NSApp.isActive { onReturn?() }
        return true
    }

    func configureControllers() {
        let pads = GCController.controllers().compactMap(\.extendedGamepad)
        controllerCount = pads.count
        for pad in pads {
            let token = String(describing: ObjectIdentifier(pad))
            pad.dpad.valueChangedHandler = { [weak self] _, x, y in
                Task { @MainActor in self?.stick(x: x, y: y, key: token + "d") }
            }
            pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
                Task { @MainActor in self?.stick(x: x, y: y, key: token + "s") }
            }
            pad.buttonA.pressedChangedHandler = onPress { $0.confirm() }   // ✕
            pad.buttonB.pressedChangedHandler = onPress { $0.back() }      // ○
            pad.buttonX.pressedChangedHandler = onPress { $0.newGame() }   // □
            pad.buttonY.pressedChangedHandler = onPress { $0.refresh() }   // △
            pad.leftShoulder.pressedChangedHandler = onPress { $0.stepFact(-1) }  // L1
            pad.rightShoulder.pressedChangedHandler = onPress { $0.stepFact(1) }  // R1
            let options = onPress { model in                               // Options
                if model.notice != nil { model.notice = nil } else { model.help.toggle() }
            }
            pad.buttonMenu.pressedChangedHandler = { [weak self] button, value, pressed in
                options(button, value, pressed)
                Task { @MainActor in self?.holdExitChord("options", pressed: pressed, pad: token) }
            }
            pad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in   // Share
                Task { @MainActor in self?.holdExitChord("share", pressed: pressed, pad: token) }
            }
        }
    }

    /// Options + Share held during a game quits it and returns to the library, saving like a normal quit.
    /// Works in the background (MAME is frontmost); a hold, so a passing press of both never ends a game.
    private func holdExitChord(_ button: String, pressed: Bool, pad: String) {
        if pressed { exitChord[pad, default: []].insert(button) } else { exitChord[pad]?.remove(button) }
        guard running != nil, exitChord.values.contains(where: { $0.count == 2 }) else {
            exitTask?.cancel()
            exitTask = nil
            return
        }
        guard exitTask == nil else { return }
        exitTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, !Task.isCancelled else { return }
            self.exitTask = nil
            self.endGame()
        }
    }

    private func onPress(_ action: @escaping @MainActor (ArcadeModel) -> Void) -> GCControllerButtonValueChangedHandler {
        { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in
                guard let self, self.claimController() else { return }
                action(self)
            }
        }
    }

    /// Moves once on press, then repeats while the stick or D-pad is held.
    private func stick(x: Float, y: Float, key: String) {
        let direction: Direction? = abs(x) > abs(y)
            ? (x > 0.5 ? .right : x < -0.5 ? .left : nil)
            : (y > 0.5 ? .up : y < -0.5 ? .down : nil)
        guard heldDirections[key] != direction else { return }
        heldDirections[key] = direction
        repeatTasks[key]?.cancel()
        repeatTasks[key] = nil
        guard let direction, claimController() else { return }
        handle(direction)
        repeatTasks[key] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(380))
            while !Task.isCancelled, let self, self.acceptsController {
                self.handle(direction)
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
    }

    // MARK: Keyboard and trackpad

    /// Returns true when the launcher used the key.
    func handleKey(_ event: NSEvent) -> Bool {
        guard running == nil, notice == nil,
              event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        switch event.keyCode {
        case KeyCode.left: handle(.left)
        case KeyCode.right: handle(.right)
        case KeyCode.up, KeyCode.down:
            handle(event.keyCode == KeyCode.up ? .up : .down)
        case KeyCode.enter, KeyCode.keypadEnter:
            if !event.isARepeat { confirm() }
        default:
            guard !help, !event.isARepeat else { return false }
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "r": refresh()
            case "n": newGame()
            case "?", "/", "h": help = true
            default: return false
            }
        }
        return true
    }

    /// Two-finger swipes and mouse wheels browse the carousel.
    func handleScroll(_ event: NSEvent) -> Bool {
        guard running == nil, !help, notice == nil, !games.isEmpty else { return false }
        if !event.momentumPhase.isEmpty { return true }
        let horizontal = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
        let delta = horizontal ? -event.scrollingDeltaX : -event.scrollingDeltaY
        if !event.hasPreciseScrollingDeltas {
            if delta != 0 { move(delta > 0 ? 1 : -1) }
            return true
        }
        scrollAccumulator += delta
        if abs(scrollAccumulator) > 50 {
            move(scrollAccumulator > 0 ? 1 : -1)
            scrollAccumulator = 0
        }
        if event.phase == .ended || event.phase == .cancelled { scrollAccumulator = 0 }
        return true
    }
}
