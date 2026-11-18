import SwiftUI

/// Settings and help. Fully usable from a controller: ↑ ↓ to move, ✕ to change, ○ or Options to close.
struct HelpView: View {
    @ObservedObject var model: ArcadeModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Settings").font(.system(size: 30, weight: .bold, design: .rounded))
                    Spacer()
                    Button("Done") { model.help = false }.keyboardShortcut(.cancelAction)
                }
                Text("Move with ↑ ↓, change with ✕ or Return, close with ○, Options or Esc.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                SettingRow(focused: model.helpFocus == .fullscreen) {
                    Toggle("Play games in full screen", isOn: $model.fullscreen)
                }
                SettingRow(focused: model.helpFocus == .autoResume) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Save on exit, resume next time", isOn: $model.autoResume)
                        Text(saveSupport).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                SettingRow(focused: model.helpFocus == .display) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Display style")
                            Spacer()
                            Picker("Display style", selection: $model.displayStyle) {
                                ForEach(DisplayStyle.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 300)
                        }
                        Text(model.displayStyle.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }

                SettingRow(focused: model.helpFocus == .music) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Toggle("Background music", isOn: $model.music)
                            Spacer()
                            if model.music {
                                Button { model.sounds.skip(-1) } label: { Image(systemName: "backward.fill") }
                                    .buttonStyle(.borderless).help("Previous theme")
                                Button { model.sounds.skip(1) } label: { Image(systemName: "forward.fill") }
                                    .buttonStyle(.borderless).help("Next theme")
                            }
                        }
                        Text(model.music ? "Now playing: \(model.nowPlaying). ← → for another theme." : "High Score opens, then today's theme: the original by day, its night version from 6 pm.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                SettingRow(focused: model.helpFocus == .interfaceSounds) {
                    Toggle("Interface sounds", isOn: $model.interfaceSounds)
                }
                SettingRow(focused: model.helpFocus == .quit) {
                    Button { NSApp.terminate(nil) } label: {
                        HStack {
                            Label("Quit Coinless", systemImage: "power")
                            Spacer()
                            Text("⌘Q").foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Divider().padding(.vertical, 4)

                section("Back to your collection",
                        "During a game, hold Options + Share for a moment, or press Esc. It quits like a normal exit, so saving works as usual.")
                section("Quick saves during play",
                        "In MAME, press Tab → Input Settings → Input Assignments (general) → User Interface, and set Save State (Quick) to L3 and Load State (Quick) to R3 (click the sticks). Use a button combination if you click the sticks by accident.")
                section("Starting over",
                        "On a saved game, press □ or N twice. The previous auto-save is kept as sta/<game>/auto.sta.bak.")
                section("Library pictures",
                        "Coinless captures each game's attract screen with MAME in the background, plus a picture of where you left off. To use your own picture, save it as art/<game>/cover.png.")

                HStack {
                    Button("Refresh games") { model.refresh() }
                    Button("Rebuild previews") { model.rebuildPreviews() }
                    Button("Open game folders") { open("games") }
                    Button("Setup guide") { open("README.md") }
                }
                .padding(.top, 4)
            }
            .padding(32)
        }
        .frame(width: 680, height: 760)
        .preferredColorScheme(.dark)
    }

    private var saveSupport: String {
        let saving = model.games.filter(\.saveStates).map(\.title)
        let notSaving = model.games.filter { !$0.saveStates }.map(\.title)
        var text = saving.isEmpty ? "None of your installed games support saves in this MAME version." : "Works with \(saving.formatted(.list(type: .and)))."
        if !notSaving.isEmpty {
            text += " \(notSaving.formatted(.list(type: .and))) always start\(notSaving.count == 1 ? "s" : "") from the beginning, because MAME can't save \(notSaving.count == 1 ? "it" : "them")."
        }
        return text + " Before the first auto-save exists, Coinless resumes your newest manual save. Turn this off to play without loading or saving."
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func open(_ path: String) {
        if let root = model.library?.root { NSWorkspace.shared.open(root.appendingPathComponent(path)) }
    }
}

struct SettingRow<Content: View>: View {
    let focused: Bool
    let content: Content

    init(focused: Bool, @ViewBuilder content: () -> Content) {
        self.focused = focused
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(focused ? 0.08 : 0.03)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(focused ? Theme.accent : .clear, lineWidth: 2))
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}
