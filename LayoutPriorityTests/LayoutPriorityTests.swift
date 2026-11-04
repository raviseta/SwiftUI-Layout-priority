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
