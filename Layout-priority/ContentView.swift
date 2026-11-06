import SwiftUI

struct ContentView: View {
    @State private var experiment = Experiment.stacks
    @State private var selectedBlock = 1
    @State private var priority = 1.0
    @State private var canvasWidth = 320.0
    @State private var showCode = false
    @State private var blockSizes: [Int: CGSize] = [:]
    @State private var stackSize = CGSize.zero
    @State private var tourStep = 0
    @State private var compactFirst = false
    @State private var prioritizedCandidate = FitCandidate.compact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    masthead
                    introduction
                    experimentPicker
                    experimentCard(availableWidth: geometry.size.width - 80)
                    controls(availableWidth: min(500, geometry.size.width - 80))
                    takeaway
                    codeCard
                    sourceLink
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .background(LabTheme.background)
        .foregroundStyle(LabTheme.ink)
        .preferredColorScheme(.dark)
        .tint(LabTheme.orange)
        .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: experiment)
        .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: priority)
        .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: selectedBlock)
        .task {
            configureLaunchScenario()
            guard ProcessInfo.processInfo.arguments.contains("--tour") else { return }
            // Repeatable hands-free tour for recording the real app in Simulator.
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                advanceTour()
            }
        }
    }

    private var masthead: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.fill").foregroundStyle(LabTheme.orange)
            Text("LAYOUT LAB").tracking(3)
            Spacer()
            Text("SWIFTUI").tracking(1.5).foregroundStyle(LabTheme.muted)
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .accessibilityElement(children: .combine)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A little priority.\nA different layout.")
                .font(.system(size: 33, weight: .bold, design: .rounded))
                .tracking(-1)
                .fixedSize(horizontal: false, vertical: true)
            Text("One modifier. Four container policies.")
                .font(.subheadline).foregroundStyle(LabTheme.muted)
        }
    }

    private var experimentPicker: some View {
        HStack(spacing: 4) {
            ForEach(Experiment.allCases) { item in
                Button { experiment = item; blockSizes = [:] } label: {
                    HStack(spacing: 6) {
                        Text(item.number).foregroundStyle(experiment == item ? LabTheme.orange : LabTheme.muted)
                        Text(item.title)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(experiment == item ? LabTheme.surface : .clear, in: .rect(cornerRadius: 12))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("experiment-\(item.rawValue)")
                .accessibilityAddTraits(experiment == item ? .isSelected : [])
            }
        }
        .padding(4).background(LabTheme.well, in: .rect(cornerRadius: 16))
    }

    private func experimentCard(availableWidth: CGFloat) -> some View {
        let minimum = experiment == .fits ? 120.0 : 240.0
        let width = min(CGFloat(max(canvasWidth, minimum)), max(0, availableWidth))
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(experiment.container, systemImage: experiment.symbol)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                Spacer()
                Circle().fill(LabTheme.mint).frame(width: 5, height: 5)
                Text("LIVE").tracking(1.5)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(LabTheme.mint)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(LabTheme.well)
                DotGrid().stroke(LabTheme.muted.opacity(0.18), lineWidth: 1)
                Group {
                    switch experiment {
                    case .stacks: stackExperiment
                    case .layers: layerExperiment
                    case .custom: customExperiment
                    case .fits:
                        FitOrderDemo(compactFirst: compactFirst, prioritizedCandidate: prioritizedCandidate, priority: priority)
                    }
                }
                .frame(width: width, height: 132)
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(LabTheme.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 168)
            HStack {
                Text(experiment == .layers ? "ZSTACK SIZE" : "PROPOSED WIDTH")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1).foregroundStyle(LabTheme.muted)
                Spacer()
                Text(experiment == .layers
                     ? "\(Int(stackSize.width.rounded())) × \(Int(stackSize.height.rounded())) pt"
                     : "\(Int(width.rounded())) pt")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("size-readout")
            }
        }
        .padding(16).background(LabTheme.surface, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.06)))
    }

    private var stackExperiment: some View {
        // Flexible shapes determine allocation; labels are overlays so they don't change it.
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                block(index).frame(minWidth: 56)
                    .layoutPriority(index == selectedBlock ? priority : 0)
            }
        }
    }

    private var layerExperiment: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(LabTheme.blockGradient(1))
            Text("Made to fit.")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(LabTheme.background)
                .padding(18).layoutPriority(priority)
        }
        // Measure before the outer frame: this is the ZStack's size, not its proposal.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { stackSize = $0 }
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(LabTheme.ink.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ZStack, text priority \(priority.formatted())")
        .accessibilityValue("\(Int(stackSize.width)) by \(Int(stackSize.height)) points")
    }

    private var customExperiment: some View {
        PriorityOrderedRow(spacing: 8) {
            ForEach(0..<3) { index in
                block(index).layoutPriority(index == selectedBlock ? priority : 0)
            }
        }
    }

    private func block(_ index: Int) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(LabTheme.blockGradient(index))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { blockSizes[index] = $0 }
            .overlay {
                VStack(spacing: 8) {
                    Text(["A", "B", "C"][index]).font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("p: \((index == selectedBlock ? priority : 0).formatted())")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                    Text("\(Int((blockSizes[index]?.width ?? 0).rounded())) pt")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(LabTheme.background.opacity(0.1), in: .capsule)
                }
                .foregroundStyle(LabTheme.background).minimumScaleFactor(0.7).padding(4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Block \(["A", "B", "C"][index])")
            .accessibilityValue("priority \((index == selectedBlock ? priority : 0).formatted()), width \(Int((blockSizes[index]?.width ?? 0).rounded())) points")
            .accessibilityIdentifier("block-\(index)")
    }

    private func controls(availableWidth: CGFloat) -> some View {
        let minimum = experiment == .fits ? 120.0 : 240.0
        let maximum = max(minimum, availableWidth)
        let widthBinding = Binding(get: { min(max(canvasWidth, minimum), maximum) }, set: { canvasWidth = $0 })
        return VStack(alignment: .leading, spacing: 16) {
            if experiment == .fits {
                VStack(alignment: .leading, spacing: 8) {
                    controlLabel("DECLARATION ORDER")
                    Picker("Declaration order", selection: $compactFirst) {
                        Text("Wide first").tag(false)
                        Text("Compact first").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("fit-order")
                }
                HStack {
                    controlLabel("PRIORITIZE")
                    Spacer()
                    ForEach(FitCandidate.allCases) { candidate in
                        Button(candidate.title) { prioritizedCandidate = candidate }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(prioritizedCandidate == candidate ? LabTheme.ink : LabTheme.surface, in: .rect(cornerRadius: 12))
                            .foregroundStyle(prioritizedCandidate == candidate ? LabTheme.background : LabTheme.ink)
                            .buttonStyle(.plain)
                            .accessibilityLabel("Prioritize \(candidate.title) candidate")
                            .accessibilityAddTraits(prioritizedCandidate == candidate ? .isSelected : [])
                    }
                }
            } else if experiment != .layers {
                HStack {
                    controlLabel("PRIORITIZE")
                    Spacer()
                    ForEach(0..<3) { index in
                        Button(["A", "B", "C"][index]) { selectedBlock = index }
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .frame(width: 44, height: 44)
                            .background(selectedBlock == index ? LabTheme.ink : LabTheme.surface, in: .rect(cornerRadius: 12))
                            .foregroundStyle(selectedBlock == index ? LabTheme.background : LabTheme.ink)
                            .buttonStyle(.plain)
                            .accessibilityLabel("Prioritize block \(["A", "B", "C"][index])")
                            .accessibilityAddTraits(selectedBlock == index ? .isSelected : [])
                    }
                }
            }
            HStack {
                controlLabel(experiment == .layers ? "TEXT PRIORITY" : "PRIORITY")
                Spacer(minLength: 10)
                ForEach([-1.0, 0, 1, 100], id: \.self) { value in
                    Button(value.formatted()) { priority = value }
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(minWidth: 40, minHeight: 44)
                        .background(priority == value ? LabTheme.orange : LabTheme.surface, in: .rect(cornerRadius: 12))
                        .foregroundStyle(priority == value ? LabTheme.background : LabTheme.ink)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Priority \(value.formatted())")
                        .accessibilityIdentifier("priority-\(Int(value))")
                        .accessibilityAddTraits(priority == value ? .isSelected : [])
                }
            }
            VStack(spacing: 2) {
                HStack {
                    controlLabel("AVAILABLE WIDTH")
                    Spacer()
                    Text("Drag to constrain").font(.system(size: 10)).foregroundStyle(LabTheme.muted)
                }
                Slider(value: widthBinding, in: minimum...maximum, step: 1)
                    .accessibilityLabel("Available width")
                    .accessibilityValue("\(Int(widthBinding.wrappedValue)) points")
            }
        }
    }

    private func controlLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1).foregroundStyle(LabTheme.muted)
    }

    private var takeaway: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.up.right").font(.system(size: 16, weight: .medium)).foregroundStyle(LabTheme.orange)
            VStack(alignment: .leading, spacing: 5) {
                Text(takeawayTitle).font(.system(size: 15, weight: .semibold))
                Text(takeawayDetail).font(.system(size: 12)).foregroundStyle(LabTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var takeawayTitle: String {
        switch experiment {
        case .stacks:
            if priority == 0 { return "Same priority. Shared space." }
            if priority < 0 { return "Negative priority waits its turn." }
            return "First in line for extra space."
        case .layers: return priority > 0 ? "The text sets the bounds." : "The flexible shape fills the proposal."
        case .custom: return "Our layout. Our priority policy."
        case .fits: return "First fit wins. Priority does not pick."
        }
    }

    private var takeawayDetail: String {
        switch experiment {
        case .stacks: "Each block keeps a 56 pt minimum. Try 1 and 100: priority is an ordering, not a size multiplier."
        case .layers: "The dashed outline is the outer frame. The solid outline measures the ZStack inside it."
        case .custom: "This row sorts by priority and gives equal widths. Ties keep their original order."
        case .fits: "Change priority: selection stays the same. Change width or declaration order: selection can change. If neither fits, the last candidate is used."
        }
    }

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { showCode.toggle() } label: {
                HStack {
                    Image(systemName: "chevron.left.forwardslash.chevron.right").foregroundStyle(LabTheme.orange)
                    Text("See the code")
                    Spacer()
                    Image(systemName: showCode ? "chevron.up" : "chevron.down").foregroundStyle(LabTheme.muted)
                }
                .font(.system(size: 12, weight: .semibold)).frame(minHeight: 32).contentShape(.rect)
            }
            .buttonStyle(.plain)
            if showCode {
                ScrollView(.horizontal) {
                    Text(codeSample).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(LabTheme.mint).textSelection(.enabled)
                }
            }
        }
        .padding(16).background(LabTheme.surface, in: .rect(cornerRadius: 16))
    }

    private var codeSample: String {
        switch experiment {
        case .stacks:
            let lines = (0..<3).map { index in
                let value = index == selectedBlock ? priority : 0
                return "    block(\(index)).frame(minWidth: 56)\n        .layoutPriority(\(value.formatted()))"
            }
            return "HStack(spacing: 8) {\n" + lines.joined(separator: "\n") + "\n}"
        case .layers:
            return """
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(gradient)
                Text("Made to fit.")
                    .padding(18)
                    .layoutPriority(\(priority.formatted()))
            }
            """
        case .custom:
            return """
            // Inside PriorityOrderedRow:
            let order = subviews.indices.sorted {
                if subviews[$0].priority == subviews[$1].priority {
                    return $0 < $1
                }
                return subviews[$0].priority > subviews[$1].priority
            }
            // Place equal-width cells in this order.
            """
        case .fits:
            let candidates: [FitCandidate] = compactFirst ? [.compact, .wide] : [.wide, .compact]
            let lines = candidates.map { candidate in
                let value = candidate == prioritizedCandidate ? priority : 0
                return "    candidate(.\(candidate.rawValue)) // \(Int(candidate.width)) pt\n        .layoutPriority(\(Int(value)))"
            }
            return "ViewThatFits(in: .horizontal) {\n" + lines.joined(separator: "\n") + "\n}"
        }
    }

    private var sourceLink: some View {
        Link(destination: URL(string: "https://nilcoalescing.com/blog/TheRoleOfLayoutPriorityInSwiftUIContainers/")!) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "book.closed")
                Text("Inspired by Natalia Panferova\nRead the article on nilcoalescing.com ↗")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 11)).foregroundStyle(LabTheme.muted)
        }
    }

    private func configureLaunchScenario() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--experiment"), arguments.indices.contains(index + 1),
           let value = Experiment(rawValue: arguments[index + 1]) { experiment = value }
        if let index = arguments.firstIndex(of: "--priority"), arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]), [-1, 0, 1, 100].contains(value) { priority = value }
    }

    private func advanceTour() {
        tourStep = (tourStep + 1) % 8
        switch tourStep {
        case 0: experiment = .stacks; selectedBlock = 1; priority = 1
        case 1: priority = 0
        case 2: priority = 1
        case 3: priority = 100
        case 4: experiment = .layers; priority = 0
        case 5: priority = 1
        case 6: experiment = .custom; selectedBlock = 2; priority = 0
        default: priority = 1
        }
    }
}

private enum Experiment: String, CaseIterable, Identifiable {
    case stacks, layers, custom, fits
    var id: Self { self }
    var number: String {
        switch self { case .stacks: "01"; case .layers: "02"; case .custom: "03"; case .fits: "04" }
    }
    var title: String {
        switch self { case .stacks: "Stacks"; case .layers: "Layers"; case .custom: "Custom"; case .fits: "Fits" }
    }
    var container: String {
        switch self { case .stacks: "HStack"; case .layers: "ZStack"; case .custom: "PriorityOrderedRow"; case .fits: "ViewThatFits" }
    }
    var symbol: String {
        switch self { case .stacks: "rectangle.split.3x1"; case .layers: "square.3.layers.3d"; case .custom: "arrow.left.arrow.right"; case .fits: "rectangle.2.swap" }
    }
}

enum LabTheme {
    static let background = Color(red: 0.04, green: 0.07, blue: 0.11)
    static let surface = Color(red: 0.08, green: 0.12, blue: 0.17)
    static let well = Color(red: 0.05, green: 0.09, blue: 0.13)
    static let ink = Color(red: 0.94, green: 0.94, blue: 0.88)
    static let muted = Color(red: 0.58, green: 0.65, blue: 0.70)
    static let orange = Color(red: 1, green: 0.61, blue: 0.36)
    static let mint = Color(red: 0.61, green: 0.85, blue: 0.73)
    static func blockGradient(_ index: Int) -> LinearGradient {
        let colors: [Color] = [Color(red: 0.56, green: 0.70, blue: 0.97), orange, mint]
        return LinearGradient(colors: [colors[index], colors[index].opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct DotGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for x in stride(from: 12.0, to: rect.width, by: 16) {
            for y in stride(from: 12.0, to: rect.height, by: 16) {
                path.addEllipse(in: CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        return path
    }
}

#Preview { ContentView() }
