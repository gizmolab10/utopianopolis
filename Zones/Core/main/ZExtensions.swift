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
    public typealias ZControl                   = NSControl
    public typealias ZMenuItem                  = NSMenuItem
    public typealias ZTextView                  = NSTextView
    public typealias ZTextField                 = NSTextField
    public typealias ZTableView                 = NSTableView
    public typealias ZStackView                 = NSStackView
    public typealias ZButtonCell                = NSButtonCell
    public typealias ZBezierPath                = NSBezierPath
    public typealias ZSearchField               = NSSearchField
    public typealias ZApplication               = NSApplication
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


    let zapplication = NSApplication.shared()


    func CGSizeFromString(_ string: String) -> CGSize {
        let size = NSSizeFromString(string)

        return CGSize(width: size.width, height: size.height)
    }


    extension NSApplication {
        func clearBadge() {
            dockTile.badgeLabel = ""
        }
    }


    extension NSColor {
        func darker(by: CGFloat) -> NSColor {
            return NSColor(calibratedHue: hueComponent, saturation: saturationComponent * 1.1, brightness: brightnessComponent / by, alpha: alphaComponent)
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


    public extension NSImage {
        public func imageRotatedByDegrees(_ degrees: CGFloat) -> NSImage {

            var imageBounds = NSZeroRect ; imageBounds.size = self.size
            let pathBounds = NSBezierPath(rect: imageBounds)
            var transform = NSAffineTransform()
            transform.rotate(byDegrees: degrees)
            pathBounds.transform(using: transform as AffineTransform)
            let rotatedBounds:CGRect = NSMakeRect(NSZeroPoint.x, NSZeroPoint.y , self.size.width, self.size.height )
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


#elseif os(iOS)


    import UIKit


    public typealias ZFont                      = UIFont
    public typealias ZView                      = UIView
    public typealias ZEvent                     = UIEvent
    public typealias ZImage                     = UIImage
    public typealias ZColor                     = UIColor
    public typealias ZButton                    = UIButton
    public typealias ZWindow                    = UIWindow
    public typealias ZSlider                    = UISlider
    public typealias ZControl                   = UIControl
    public typealias ZMenuItem                  = UIMenuItem
    public typealias ZTextView                  = UITextView
    public typealias ZTextField                 = UITextField
    public typealias ZTableView                 = UITableView
    public typealias ZBezierPath                = UIBezierPath
    public typealias ZSearchField               = UISearchBar
    public typealias ZApplication               = UIApplication
    public typealias ZViewController            = UIViewController
    public typealias ZSegmentedControl          = UISegmentedControl
    public typealias ZGestureRecognizer         = UIGestureRecognizer
    public typealias ZTextFieldDelegate         = UITextFieldDelegate
    public typealias ZProgressIndicator         = UIActivityIndicatorView
    public typealias ZTableViewDelegate         = UITableViewDelegate
    public typealias ZSearchFieldDelegate       = UISearchBarDelegate
    public typealias ZTableViewDataSource       = UITableViewDataSource
    public typealias ZApplicationDelegate       = UIApplicationDelegate
    public typealias ZGestureRecognizerDelegate = UIGestureRecognizerDelegate


    let zapplication = ZApplication.shared


    func NSStringFromSize(_ size: CGSize) -> String {
        return NSStringFromCGSize(size)
    }


    extension UIColor {
        func darker(by: CGFloat) -> UIColor {
            var        hue: CGFloat = 0.0
            var      alpha: CGFloat = 0.0
            var saturation: CGFloat = 0.0
            var brightness: CGFloat = 0.0

            self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

            return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        }
    }
    


    extension UIApplication {

        func presentError(_ error: NSError) {}

        
        func clearBadge() {
            applicationIconBadgeNumber += 1
            applicationIconBadgeNumber  = 0

            cancelAllLocalNotifications()
        }
    }


    extension UIWindow {
        @discardableResult func makeFirstResponder(_ responder: UIResponder?) -> Bool {
            return responder == nil ? false : responder!.becomeFirstResponder()
        }
    }

    extension UIView {
        var      zlayer:               CALayer { get { return layer } }
        var recognizers: [ZGestureRecognizer]? { get { return gestureRecognizers } }


        func clear() { zlayer.isOpaque = false }
        func display() {}


        @discardableResult func createGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?, clicksRequired: Int) -> ZGestureRecognizer {
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
        func abortEditing() {}
    }


    public extension UISlider {
        var doubleValue: Double {
            get { return Double(value) }
            set { value = Float(newValue) }
        }
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
        gTravelManager.debugCheck()
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
        gControllersManager.signalFor(object, regarding: regarding, onCompletion: nil)
    }


    func detectWithMode(_ mode: ZStorageMode, block: ToBooleanClosure) -> Bool {
        let savedMode = gStorageMode
        gStorageMode  = mode
        let    result = block()
        gStorageMode  = savedMode

        return result
    }


    func invokeWithMode(_ mode: ZStorageMode?, block: Closure) {
        if  mode == nil || mode == gStorageMode {
            block()
        } else {
            let savedMode = gStorageMode
            gStorageMode  = mode!

            block()

            gStorageMode  = savedMode
        }
    }


    func manifestNameForMode(_ mode: ZStorageMode) -> String {
        return "\(manifestNameKey).\(mode.rawValue)"
    }


    func addUndo<TargetType : AnyObject>(withTarget target: TargetType, handler: @escaping (TargetType) -> Swift.Void) {
        gUndoManager.registerUndo(withTarget:target, handler: { iObject in
            gUndoManager.beginUndoGrouping()
            handler(iObject)
            gUndoManager.endUndoGrouping()
        })
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


    func index(at: Int) -> Index {
        var position = at

        repeat {
            if let index = index(startIndex, offsetBy: position, limitedBy: endIndex) {
                return index
            }

            position -= 1
        } while position > 0

        return startIndex
    }


    func substring(from: Int) -> String {
        return substring(from: index(at: from))
    }


    func substring(to: Int) -> String {
        return substring(to: index(at: to))
    }


    func substring(with r: Range<Int>) -> String {
        let startIndex = index(at: r.lowerBound)
        let   endIndex = index(at: r.upperBound)

        return substring(with: startIndex..<endIndex)
    }
}


extension Character {
    var asciiValue: UInt32? {
        return String(self).unicodeScalars.filter{$0.isASCII}.first?.value
    }
}


extension ZView {


    func clearGestures() {
        if recognizers != nil {
            for recognizer in recognizers! {
                removeGestureRecognizer(recognizer)
            }
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


    func applyToAllSubviews(_ closure: ViewClosure) {
        for view in subviews {
            closure(view)

            view.applyToAllSubviews(closure)
        }
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

