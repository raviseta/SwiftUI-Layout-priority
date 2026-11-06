import XCTest
import SwiftUI
@testable import Layout_priority

/// These checks measure real SwiftUI views, rather than reimplementing stack allocation.
@MainActor
final class LayoutPriorityTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testHStackPriorityGroups() async throws {
        for (priority, expected) in [
            (0.0, [101.333, 101.333, 101.333]),
            (1.0, [56.0, 192.0, 56.0]),
            (100.0, [56.0, 192.0, 56.0]),
            (-1.0, [124.0, 56.0, 124.0])
        ] {
            let recorder = Measurements()
            let view = HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Color.orange.frame(minWidth: 56)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { recorder.frames[index] = $0 }
                        .layoutPriority(index == 1 ? priority : 0)
                }
            }.frame(width: 320, height: 132)
            host(view)
            try await waitForFrames(3, recorder)
            for index in 0..<3 {
                XCTAssertEqual(try XCTUnwrap(recorder.frames[index]).width, expected[index], accuracy: 1,
                               "priority \(priority), block \(index)")
            }
        }
    }

    func testZStackMeasuresTextWhenTextHasHighestPriority() async throws {
        var measured: [Double: CGSize] = [:]
        for priority in [0.0, 1, 100, -1] {
            let recorder = Measurements()
            let view = ZStack {
                Color.orange
                Text("Made to fit.").font(.system(size: 20, weight: .bold, design: .rounded))
                    .padding(18).layoutPriority(priority)
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { recorder.frames[0] = $0 }
            .frame(width: 320, height: 132)
            host(view)
            try await waitForFrames(1, recorder)
            measured[priority] = try XCTUnwrap(recorder.frames[0]).size
        }
        XCTAssertEqual(measured[0], CGSize(width: 320, height: 132))
        XCTAssertEqual(measured[-1], measured[0])
        XCTAssertEqual(measured[1], measured[100])
        XCTAssertLessThan(try XCTUnwrap(measured[1]).width, 320)
        XCTAssertLessThan(try XCTUnwrap(measured[1]).height, 132)
    }

    func testCustomRowReordersWithoutChangingWidthsAndPreservesTies() async throws {
        for (priority, order) in [(0.0, [0, 1, 2]), (1.0, [2, 0, 1]), (-1.0, [0, 1, 2])] {
            let recorder = Measurements()
            let view = PriorityOrderedRow {
                ForEach(0..<3) { index in
                    Color.orange
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { recorder.frames[index] = $0 }
                        .layoutPriority(index == 2 ? priority : 0)
                }
            }.frame(width: 320, height: 132)
            host(view)
            try await waitForFrames(3, recorder)
            let actualOrder = recorder.frames.keys.sorted { recorder.frames[$0]!.minX < recorder.frames[$1]!.minX }
            XCTAssertEqual(actualOrder, order)
            for frame in recorder.frames.values { XCTAssertEqual(frame.width, 101.333, accuracy: 1) }
        }
    }

    func testCustomRowHandlesEmptyAndNarrowProposals() async throws {
        let recorder = Measurements()
        let view = VStack {
            PriorityOrderedRow { EmptyView() }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { recorder.frames[3] = $0 }
            PriorityOrderedRow(spacing: 100) {
                ForEach(0..<3) { index in
                    Color.orange
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { recorder.frames[index] = $0 }
                }
            }.frame(width: 10, height: 20)
        }
        host(view)
        // Zero-width children are valid in this constrained proposal.
        for _ in 0..<100 {
            if recorder.frames.count == 4 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(try XCTUnwrap(recorder.frames[3]).size, .zero)
        for index in 0..<3 {
            let frame = try XCTUnwrap(recorder.frames[index])
            XCTAssertGreaterThanOrEqual(frame.width, 0)
            XCTAssertTrue(frame.minX.isFinite)
        }
    }

    func testViewThatFitsUsesDeclarationOrderRatherThanChildPriority() async throws {
        for compactFirst in [false, true] {
            for prioritizedCandidate in FitCandidate.allCases {
                for priority in [-1.0, 0, 1, 100] {
                    for width in [320.0, 240, 160] {
                        let recorder = Measurements()
                        let view = FitOrderDemo(compactFirst: compactFirst, prioritizedCandidate: prioritizedCandidate, priority: priority)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { recorder.frames[0] = $0 }
                            .frame(width: width, height: 132)
                        host(view)
                        try await waitForFrames(1, recorder)
                        // With no fitting candidate, the last declaration is the fallback.
                        let expectedWidth: CGFloat = compactFirst
                            ? (width >= 180 ? 180 : 300)
                            : (width >= 300 ? 300 : 180)
                        XCTAssertEqual(try XCTUnwrap(recorder.frames[0]).width, expectedWidth, accuracy: 1,
                                       "compactFirst=\(compactFirst), target=\(prioritizedCandidate), priority=\(priority), width=\(width)")
                    }
                }
            }
        }
    }

    func testFixedSizeAxesControlWhetherHigherPrioritySiblingGetsMoreWidth() async throws {
        let reference = Measurements()
        host(Text("Account settings").font(.system(size: 18)).fixedSize()
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { reference.frames[0] = $0 })
        try await waitForFrames(1, reference)
        let idealWidth = try XCTUnwrap(reference.frames[0]).width

        for fixesSize in [false, true] {
            for priority in [1.0, 100] {
                let recorder = Measurements()
                let view = HStack(spacing: 8) {
                    Text("Account settings").font(.system(size: 18))
                        .lineLimit(1)
                        // Keep ideal height in both cases; only horizontal fixing changes.
                        .fixedSize(horizontal: fixesSize, vertical: true)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { recorder.frames[0] = $0 }
                    Text("A longer description that must truncate").font(.system(size: 18))
                        .lineLimit(1)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { recorder.frames[1] = $0 }
                        .layoutPriority(priority)
                }.frame(width: 240, height: 44)
                host(view)
                try await waitForFrames(2, recorder)
                let titleWidth = try XCTUnwrap(recorder.frames[0]).width
                let descriptionWidth = try XCTUnwrap(recorder.frames[1]).width
                if fixesSize {
                    XCTAssertEqual(titleWidth, idealWidth, accuracy: 1)
                    XCTAssertLessThan(descriptionWidth, 240 - idealWidth)
                } else {
                    XCTAssertLessThan(titleWidth, idealWidth)
                    XCTAssertGreaterThan(descriptionWidth, 240 - idealWidth)
                }
                XCTAssertLessThanOrEqual(titleWidth + descriptionWidth + 8, 241)
            }
        }
    }

    private func host<V: View>(_ view: V) {
        window?.isHidden = true
        let controller = UIHostingController(rootView: view)
        let newWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        newWindow.rootViewController = controller
        newWindow.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window = newWindow
    }

    private func waitForFrames(_ count: Int, _ recorder: Measurements) async throws {
        for _ in 0..<100 {
            if recorder.frames.count == count && recorder.frames.values.allSatisfy({ $0.width > 0 }) { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Timed out waiting for SwiftUI geometry")
    }
}

@MainActor
private final class Measurements {
    var frames: [Int: CGRect] = [:]
}
