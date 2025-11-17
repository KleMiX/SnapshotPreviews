//
//  PreviewBaseTest.swift
//
//
//  Created by Noah Martin on 8/9/24.
//

import Foundation
import XCTest

struct DiscoveredPreview {
    let typeName: String
    let displayName: String?
    let devices: [String]
    let orientations: [String]
    let numberOfPreviews: Int
}

struct DiscoveredPreviewAndIndex {
    let preview: DiscoveredPreview
    let index: Int
}

var previews: [DiscoveredPreviewAndIndex] = []
private var previewsBySelector: [String: DiscoveredPreviewAndIndex] = [:]

@objc(EMGPreviewBaseTest)
open class PreviewBaseTest: XCTestCase {
    
    static var signatureCreator: NSObject?
    
    @objc
    static func swizzle(_ signatureCreator: NSObject) {
        self.signatureCreator = signatureCreator
        let originalSelector = NSSelectorFromString("testInvocations")
        let swizzledSelector = #selector(swizzled_testInvocations)
        let originalMethod = class_getClassMethod(XCTestCase.self, originalSelector)
        let swizzledMethod = class_getClassMethod(PreviewBaseTest.self, swizzledSelector)
        guard let originalMethod, let swizzledMethod else {
            print("Method not found")
            return
        }
        
        let swizzledImp = method_getImplementation(swizzledMethod)
        let currentClass: AnyClass = object_getClass(PreviewBaseTest.self)!
        class_addMethod(currentClass, originalSelector, swizzledImp, method_getTypeEncoding(originalMethod))
    }
    
    @objc @MainActor
    static func swizzled_testInvocations() -> [AnyObject] {
        let className = NSStringFromClass(self)
        // Only support running this test if it’s a subclass outside of the SnapshottingTests module
        if className == "EMGPreviewBaseTest" || className.hasPrefix("SnapshottingTests.") {
            return []
        }
        
        let dynamicTestSelectors = addMethods().sorted()
        var invocations: [AnyObject] = []
        guard let signatureCreator else {
            return invocations
        }
        for testName in dynamicTestSelectors {
            let invocation = signatureCreator.perform(NSSelectorFromString("create:"), with: testName).takeRetainedValue() as! NSObject
            invocations.append(invocation)
        }
        return invocations
    }
    
    @MainActor
    class func addMethods() -> [String] {
        var dynamicTestSelectors: [String] = []
        let discoveredPreviews = discoverPreviews()
        previews = []
        previewsBySelector = [:]
        var i = 0
        
        let currentDeviceName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
        
        for discoveredPreview in discoveredPreviews {
            let typeName = discoveredPreview.typeName
            let displayName = discoveredPreview.displayName ?? typeName
            let count = discoveredPreview.numberOfPreviews
            
            for j in 0..<count {
                if let currentDeviceName {
                    let specifiedPreviewDevice = (j < discoveredPreview.devices.count) ? discoveredPreview.devices[j] : ""
                    guard specifiedPreviewDevice.isEmpty || specifiedPreviewDevice == currentDeviceName else {
                        continue
                    }
                }
                
                let orientation = (j < discoveredPreview.orientations.count) ? discoveredPreview.orientations[j] : "portrait"
                let testSelectorName = "\(orientation)-\(displayName)-\(j)-\(i)"
                dynamicTestSelectors.append(testSelectorName)
                
                let preview = DiscoveredPreviewAndIndex(preview: discoveredPreview, index: j)
                previews.append(preview)
                previewsBySelector[testSelectorName] = preview
                
                let sel = NSSelectorFromString(testSelectorName)
                let rawPtr = unsafeBitCast(dynamicTestMethod, to: UnsafeRawPointer.self)
                let success = class_addMethod(self, sel, OpaquePointer(rawPtr), "v@:")
                if !success {
                    print("Error adding method \(testSelectorName)")
                }
                i += 1
            }
        }
        
        return dynamicTestSelectors
    }
    
    @MainActor
    func testPreview(_ preview: DiscoveredPreviewAndIndex) {
        print("This should be implemented by a subclass")
    }
    
    @MainActor
    class func discoverPreviews() -> [DiscoveredPreview] {
        print("This should be implemented by a subclass")
        return []
    }
}

@MainActor
private let dynamicTestMethod: @convention(c) (AnyObject, Selector) -> Void = { (self, _cmd) in
    let selectorName = NSStringFromSelector(_cmd)
    
    // Prefer exact mapping; fall back to parsed index only if present and in-bounds
    let resolvedPreview: DiscoveredPreviewAndIndex? = {
        if let p = previewsBySelector[selectorName] { return p }
        if let last = selectorName.split(separator: "-").last,
           let idx = Int(last),
           previews.indices.contains(idx) {
            return previews[idx]
        }
        return nil
    }()
    
    guard let preview = resolvedPreview else {
        if let testCase = self as? PreviewBaseTest {
            XCTFail("No preview registered for selector \(selectorName)")
        }
        return
    }
    
    if let selfAsBase = self as? PreviewBaseTest {
        selfAsBase.testPreview(preview)
    }
}
