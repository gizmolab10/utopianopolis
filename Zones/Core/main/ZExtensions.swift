//
//  ZExtensions.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


#if os(OSX)


    import Cocoa


    public typealias ZFont                      = NSFont
    public typealias ZView                      = NSView
    public typealias ZEvent                     = NSEvent
    public typealias ZImage                     = NSImage
    public typealias ZColor                     = NSColor
    public typealias ZButton                    = NSButton
    public typealias ZSlider                    = NSSlider
    public typealias ZWindow                    = NSWindow
    public typealias ZTextField                 = NSTextField
    public typealias ZTableView                 = NSTableView
    public typealias ZStackView                 = NSStackView
    public typealias ZColorWell                 = NSColorWell
    public typealias ZBezierPath                = NSBezierPath
    public typealias ZSearchField               = NSSearchField
    public typealias ZApplication               = NSApplication
    public typealias ZTableRowView              = NSTableRowView
    public typealias ZViewController            = NSViewController
    public typealias ZSegmentedControl          = NSSegmentedControl
    public typealias ZGestureRecognizer         = NSGestureRecognizer
    public typealias ZProgressIndicator         = NSProgressIndicator
    public typealias ZTextFieldDelegate         = NSTextFieldDelegate
    public typealias ZTableViewDelegate         = NSTableViewDelegate
    public typealias ZTableViewDataSource       = NSTableViewDataSource
    public typealias ZSearchFieldDelegate       = NSSearchFieldDelegate
    public typealias ZApplicationDelegate       = NSApplicationDelegate
    public typealias ZGestureRecognizerDelegate = NSGestureRecognizerDelegate


    let zapplication = ZApplication.shared()


    extension ZApplication {
        func clearBadge() {
            dockTile.badgeLabel = ""
        }
    }


    extension NSView {
        var      zlayer:               CALayer { get { wantsLayer = true; return layer! } set { layer = newValue } }
        var recognizers: [NSGestureRecognizer] { get { return gestureRecognizers } }


        func clear() {
            zlayer.backgroundColor = ZColor.clear.cgColor
        }


        @discardableResult func createGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?, clicksRequired: Int) -> NSGestureRecognizer {
            let                            gesture = NSClickGestureRecognizer(target: target, action: action)
            gesture.numberOfClicksRequired         = clicksRequired
            gesture.delaysPrimaryMouseButtonEvents = false
            gesture.delegate                       = target

            addGestureRecognizer(gesture)

            return gesture
        }
    }


    extension NSButton {
        var isCircular: Bool {
            get { return true }
            set { bezelStyle = newValue ? .circular : .rounded }
        }

        var onHit: Selector? {
            get { return action }
            set { action = newValue; target = self } }
    }


    extension NSTextField {
        var textAlignment : NSTextAlignment { get { return alignment } set { alignment = newValue } }
        var text: String? {
            get { return stringValue }
            set { stringValue = newValue! }
        }
    }


    extension NSSegmentedControl {
        var selectedSegmentIndex: Int {
            get { return selectedSegment }
            set { selectedSegment = newValue }
        }
    }


    extension NSProgressIndicator {
        func startAnimating() { startAnimation(self) }
        func  stopAnimating() {  stopAnimation(self) }
    }


#elseif os(iOS)


    import UIKit


    public typealias ZFont                      = UIFont
    public typealias ZView                      = UIView
    public typealias ZEvent                     = UIEvent
    public typealias ZImage                     = UIImage
    public typealias ZColor                     = UIColor
    public typealias ZButton                    = UIButton
    public typealias ZWindow                    = UIWindow
    public typealias ZTextField                 = UITextField
    public typealias ZBezierPath                = UIBezierPath
    public typealias ZApplication               = UIApplication
    public typealias ZViewController            = UIViewController
    public typealias ZSegmentedControl          = UISegmentedControl
    public typealias ZGestureRecognizer         = UIGestureRecognizer
    public typealias ZTextFieldDelegate         = UITextFieldDelegate
    public typealias ZProgressIndicator         = UIActivityIndicatorView
    public typealias ZApplicationDelegate       = UIApplicationDelegate
    public typealias ZGestureRecognizerDelegate = UIGestureRecognizerDelegate


    let zapplication = ZApplication.shared


    extension UIApplication {

        func presentError(_ error: NSError) {}

        
        func clearBadge() {
            applicationIconBadgeNumber += 1
            applicationIconBadgeNumber  = 0

            cancelAllLocalNotifications()
        }
    }


    extension UIView {
        var      zlayer:              CALayer { get { return layer } }
        var recognizers: [ZGestureRecognizer] { get { return gestureRecognizers! } }


        func clear() { zlayer.isOpaque = false }
        func display() {}


        @discardableResult func createGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?, clicksRequired: Int) -> NSGestureRecognizer {
            let              gesture = UITapGestureRecognizer(target: target, action: action)
            isUserInteractionEnabled = true

            if recognizers != nil {
                clearGestures()
            }

            addGestureRecognizer(gesture)

            return gesture
        }
    }


    extension UISegmentedControl {
        var selectedSegment: Int { get { return selectedSegmentIndex } }
    }


    extension UITextField {
        var isBordered : Bool { get { return borderStyle != .none } set { borderStyle = (newValue ? .line : .none) } }
    }


    extension UIButton {
        @objc func nuttin() {}


        var onHit: Selector { get { return #selector(nuttin) } set { } }


        var title: String? {
            get { return title(for: .normal) }
            set { setTitle(newValue, for: .normal) }
        }

        var isCircular: Bool {
            get { return true }
            set { }
        }
    }


#endif


typealias ZStorageDict = [String : NSObject]


extension NSObject {
    func toConsole(_ loggable: Any?) {
//        print(loggable)
    }


    func debugCheck() {
        travelManager.debugCheck()
    }


    func report(_ iMessage: Any?) {
        if iMessage != nil {
            print(iMessage!)
        }
    }


    func reportError(_ iError: Any?) {
        if let error: NSError = iError as? NSError, let waitForIt = error.userInfo[CKErrorRetryAfterKey] {
            print(waitForIt)
        } else if let error: CKError = iError as? CKError {
            print(error.localizedDescription)
        } else if iError != nil {
            print(iError!)
        }
    }


    func signalFor(_ object: NSObject?, regarding: ZSignalKind) {
        controllersManager.signalFor(object, regarding: regarding, onCompletion: nil)
    }


    func detectWithMode(_ mode: ZStorageMode, block: BooleanClosure) -> Bool {
        let savedMode = gStorageMode
        gStorageMode  = mode
        let    result = block()
        gStorageMode  = savedMode

        return result
    }


    func invokeWithMode(_ mode: ZStorageMode, block: Closure) {
        let             savedMode = gStorageMode
        gStorageMode = mode

        block()

        gStorageMode = savedMode
    }
}


extension CGRect {
    var center : CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}


extension String {
    var asciiArray: [UInt32] {
        return unicodeScalars.filter{$0.isASCII}.map{$0.value}
    }


    func heightForFont(_ font: ZFont) -> CGFloat {
        return sizeWithFont(font).height
    }


    func widthForFont(_ font: ZFont) -> CGFloat {
        return sizeWithFont(font).width + 4.0
    }


    func sizeWithFont(_ font: ZFont) -> CGSize {
        let   rect = CGSize(width: 1000000, height: 1000000)
        let bounds = self.boundingRect(with: rect, options: .usesLineFragmentOrigin, attributes: [NSFontAttributeName: font], context: nil)

        return bounds.size
    }
}


extension Character {
    var asciiValue: UInt32? {
        return String(self).unicodeScalars.filter{$0.isASCII}.first?.value
    }
}


extension ZColor {
    func darker(by: CGFloat) -> ZColor { return ZColor(calibratedHue: hueComponent, saturation: saturationComponent * 1.1, brightness: brightnessComponent / by, alpha: alphaComponent) }
}


extension ZView {


    func clearGestures() {
        for recognizer in recognizers {
            removeGestureRecognizer(recognizer)
        }
    }


    func addBorder(thickness: CGFloat, radius: CGFloat, color: CGColor) {
        zlayer.cornerRadius = radius
        zlayer.borderWidth  = thickness
        zlayer.borderColor  = color
    }


    func addBorderRelative(thickness: CGFloat, radius: CGFloat, color: CGColor) {
        let            size = self.bounds.size
        let radius: CGFloat = min(size.width, size.height) * radius

        self.addBorder(thickness: thickness, radius: radius, color: color)
    }
}


//extension NSAttributedString {
//    func heightWithConstrainedWidth(width: CGFloat) -> CGFloat {
//        let constraint = CGSize(width: width, height: .greatestFiniteMagnitude)
//        let boundingBox = boundingRect(with: constraint, options: .usesLineFragmentOrigin, context: nil)
//
//        return boundingBox.height
//    }
//
//    func widthWithConstrainedHeight(height: CGFloat) -> CGFloat {
//        let constraint = CGSize(width: .greatestFiniteMagnitude, height: height)
//        let boundingBox = boundingRect(with: constraint, options: .usesLineFragmentOrigin, context: nil)
//
//        return boundingBox.width
//    }
//}


public extension ZImage {
    public func imageRotatedByDegrees(_ degrees: CGFloat) -> ZImage {

        var imageBounds = NSZeroRect ; imageBounds.size = self.size
        let pathBounds = NSBezierPath(rect: imageBounds)
        var transform = NSAffineTransform()
        transform.rotate(byDegrees: degrees)
        pathBounds.transform(using: transform as AffineTransform)
        let rotatedBounds:NSRect = NSMakeRect(NSZeroPoint.x, NSZeroPoint.y , self.size.width, self.size.height )
        let rotatedImage = NSImage(size: rotatedBounds.size)

        //Center the image within the rotated bounds
        imageBounds.origin.x = NSMidX(rotatedBounds) - (NSWidth(imageBounds) / 2)
        imageBounds.origin.y  = NSMidY(rotatedBounds) - (NSHeight(imageBounds) / 2)

        // Start a new transform
        transform = NSAffineTransform()
        // Move coordinate system to the center (since we want to rotate around the center)
        transform.translateX(by: +(NSWidth(rotatedBounds) / 2 ), yBy: +(NSHeight(rotatedBounds) / 2))
        transform.rotate(byDegrees: degrees)
        // Move the coordinate system bak to normal
        transform.translateX(by: -(NSWidth(rotatedBounds) / 2 ), yBy: -(NSHeight(rotatedBounds) / 2))
        // Draw the original image, rotated, into the new image
        rotatedImage.lockFocus()
        transform.concat()
        self.draw(in: imageBounds, from: NSZeroRect, operation: .copy, fraction: 1.0)
        rotatedImage.unlockFocus()

        return rotatedImage
    }
}

