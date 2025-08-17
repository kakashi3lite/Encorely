import Foundation
import SnapshotTesting
import SwiftUI

enum SnapshotConfig {
    static var defaultDevices: [(String, CGSize)] = [
        ("iPhone12Pro", CGSize(width: 390, height: 844)),
        ("iPadPro11", CGSize(width: 834, height: 1194)),
        ("Mac", CGSize(width: 1024, height: 768)),
    ]

    static var defaultPrecision: Float = 0.99

    static func configureForTesting() {
        #if os(macOS)
            // Ensure consistent rendering environment
            SnapshotTesting.diffTool = "ksdiff"
            isRecording = false
        #endif
    }

    static func snapshotView<V: View>(
        _ view: V,
        as _: String,
        size: CGSize? = nil,
        precision _: Float = defaultPrecision
    ) -> NSHostingController<V> {
        let controller = NSHostingController(rootView: view)
        if let size {
            controller.view.frame = CGRect(origin: .zero, size: size)
        }
        return controller
    }

    static func verifyView(
        _ view: some View,
        name: String,
        devices: [(String, CGSize)] = defaultDevices,
        precision: Float = defaultPrecision,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        for (device, size) in devices {
            let sizedView = view.frame(width: size.width, height: size.height)
            let controller = snapshotView(sizedView, as: name)

            assertSnapshot(
                matching: controller,
                as: .image(size: size, precision: precision),
                named: "\(name)_\(device)",
                file: file,
                testName: testName,
                line: line
            )
        }
    }

    static func verifyViewInDarkMode(
        _ view: some View,
        name: String,
        devices: [(String, CGSize)] = defaultDevices,
        precision: Float = defaultPrecision,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        for (device, size) in devices {
            let sizedView = view
                .frame(width: size.width, height: size.height)
                .preferredColorScheme(.dark)

            let controller = snapshotView(sizedView, as: name)

            assertSnapshot(
                matching: controller,
                as: .image(size: size, precision: precision),
                named: "\(name)_\(device)_dark",
                file: file,
                testName: testName,
                line: line
            )
        }
    }
}
