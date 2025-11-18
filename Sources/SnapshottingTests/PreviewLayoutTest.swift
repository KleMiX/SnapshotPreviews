//
//  PreviewLayoutTest.swift
//  
//
//  Created by Noah Martin on 8/9/24.
//

import Foundation
@_implementationOnly import SnapshotPreviewsCore
import SwiftUI
import XCTest

/// A test class for verifying Xcode previews by forcing a layout pass on each one.
///
/// This class is designed to discover and test SwiftUI previews to ensure they can be laid out without crashing.
/// It provides mechanisms for filtering previews and performs layout tests on different platforms.
open class PreviewLayoutTest: PreviewBaseTest, PreviewFilters {
    
    /// Returns an optional array of preview names to be included in the snapshot testing. This also supports Regex format.
    ///
    /// Override this method to specify which previews should be included in the test.
    /// - Returns: An optional array of String containing the names of previews to be included.
    open class func snapshotPreviews() -> [String]?  {
        nil
    }
    
    /// Returns an optional array of preview names to be excluded from the snapshot testing. This also supports Regex format
    ///
    /// Override this method to specify which previews should be excluded from the test.
    /// - Returns: An optional array of String containing the names of previews to be excluded.
    open class func excludedSnapshotPreviews() -> [String]? {
        nil
    }
    
    static private var previews: [PreviewType] = []
    
    /// Discovers all relevant previews based on inclusion and exclusion filters. Subclasses should NOT override this method.
    ///
    /// This method uses `FindPreviews` to locate all previews, applying any specified filters.
    /// - Returns: An array of `DiscoveredPreview` objects representing the found previews.
    @MainActor
    override class func discoverPreviews() -> [DiscoveredPreview] {
        previews = FindPreviews.findPreviews(included: Self.snapshotPreviews(), excluded: Self.excludedSnapshotPreviews())
        return previews.map { DiscoveredPreview.from(previewType: $0) }
    }
    
    /// Tests a specific preview by performing a layout pass. Subclasses should NOT override this method.
    ///
    /// This method creates a hosting controller for the preview and forces a layout pass to verify
    /// that no crashes occur during the process.
    ///
    /// - Parameter preview: A `DiscoveredPreviewAndIndex` object representing the preview to be tested.
    @MainActor
    override func testPreview(_ preview: DiscoveredPreviewAndIndex) {
        guard let pt = Self.previews.first(where: { $0.typeName == preview.preview.typeName }) else {
            XCTFail("Preview type not found: \(preview.preview.typeName)")
            return
        }
        guard pt.previews.indices.contains(preview.index) else {
            XCTFail("Preview index \(preview.index) out of bounds (count: \(pt.previews.count)) for \(pt.typeName)")
            return
        }
        let selected = pt.previews[preview.index]
        
#if canImport(UIKit) && !os(watchOS)
        let hostingVC = UIHostingController(rootView: AnyView(selected.view()))
#if os(visionOS) || os(watchOS)
        hostingVC.view.sizeThatFits(CGSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
#else
        hostingVC.view.sizeThatFits(UIScreen.main.bounds.size)
#endif
#elseif canImport(AppKit)
        let hostingVC = NSHostingController(rootView: AnyView(selected.view()))
        _ = hostingVC.sizeThatFits(in: NSScreen.main!.frame.size)
#else
        _ = ImageRenderer(content: AnyView(selected.view())).uiImage
#endif
    }
}
