import SwiftUI

enum FitCandidate: String, CaseIterable, Identifiable {
    case wide, compact

    var id: Self { self }
    var title: String { self == .wide ? "Wide" : "Compact" }
    var width: CGFloat { self == .wide ? 300 : 180 }
}

/// Uses SwiftUI's actual selection policy. Child priority is deliberately independent
/// of declaration order, so changing it cannot secretly reorder the candidates.
struct FitOrderDemo: View {
    var compactFirst = false
    var prioritizedCandidate = FitCandidate.compact
    var priority = 1.0

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if compactFirst {
                candidate(.compact)
                candidate(.wide)
            } else {
                candidate(.wide)
                candidate(.compact)
            }
        }
    }

    private func candidate(_ candidate: FitCandidate) -> some View {
        let value = candidate == prioritizedCandidate ? priority : 0
        let isFirst = (candidate == .compact) == compactFirst
        return RoundedRectangle(cornerRadius: 14)
            .fill(LabTheme.blockGradient(candidate == .wide ? 0 : 2))
            .overlay {
                VStack(spacing: 8) {
                    Text(candidate.title)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                    Text("\(Int(candidate.width)) pt · p: \(value.formatted())")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    Text(isFirst ? "Declared first" : "Declared second · fallback")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(LabTheme.background)
            }
            // Fixed candidate sizes make the width threshold independent of text metrics.
            .frame(width: candidate.width, height: 104)
            .layoutPriority(value)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(candidate.title) candidate")
            .accessibilityValue("\(Int(candidate.width)) points, priority \(value.formatted()), declared \(isFirst ? "first" : "second")")
            .accessibilityIdentifier("fit-candidate-\(candidate.rawValue)")
    }
}
