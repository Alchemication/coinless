import SwiftUI

/// One researched fact at a time, turning over on its own like an attract-mode loop.
/// ↑ ↓, L1 R1 or a click turn it early; nothing needs a press.
struct FactTicker: View {
    @ObservedObject var model: ArcadeModel
    let tint: Color

    var body: some View {
        if let current = model.currentFact {
            VStack(spacing: 10) {
                ZStack {
                    VStack(spacing: 7) {
                        HStack(spacing: 10) {
                            Label(current.fact.kind.label, systemImage: current.fact.kind.symbol).foregroundStyle(tint)
                            Text("\(current.index + 1)/\(current.count)").foregroundStyle(.white.opacity(0.32))
                        }
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        Text(current.fact.text)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                            .frame(height: 40, alignment: .top)
                    }
                    .id("\(model.active?.id ?? "")-\(current.index)")
                    .transition(.opacity.combined(with: .offset(y: 6)))
                }
                ReadingBar(tint: tint, duration: GameFacts.readingTime(current.fact.text))
                    .id(model.factCycle)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 640)
            .contentShape(Rectangle())
            .onTapGesture { model.stepFact(1) }
            .help("Next fact (↓ or R1)")
        }
    }
}

/// Fills while a fact is up, so the next one never arrives as a surprise.
struct ReadingBar: View {
    let tint: Color
    let duration: Double
    @State private var progress: CGFloat = 0

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.08))
            .frame(width: 96, height: 3)
            .overlay(alignment: .leading) {
                Capsule().fill(tint.opacity(0.85)).frame(width: 96 * progress, height: 3)
            }
            .onAppear { withAnimation(.linear(duration: duration)) { progress = 1 } }
    }
}
