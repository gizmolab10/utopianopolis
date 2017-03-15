//
//  ZonesExtensions.swift
//  Zones
//
//  Created by Jonathan Sand on 1/31/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
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
public typealias ZEventFlags                = NSEventModifierFlags
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
public typealias ZGestureRecognizerState    = NSGestureRecognizerState
public typealias ZGestureRecognizerDelegate = NSGestureRecognizerDelegate


let gVerticalWeight = 1.0
let    zapplication = NSApplication.shared()
let      mainWindow = ZoneWindow.window!


func CGSizeFromString(_ string: String) -> CGSize {
    let size = NSSizeFromString(string)

    return CGSize(width: size.width, height: size.height)
}


extension NSObject {
    var  lineThicknessDivisor: CGFloat { return  1.0 }
    var highlightHeightOffset: CGFloat { return -3.0 }
    func assignAsFirstResponder(_ responder: NSResponder?) {
        mainWindow.makeFirstResponder(responder)
    }
}


extension NSApplication {
    func clearBadge() {
        dockTile.badgeLabel = ""
    }
}


extension NSEventModifierFlags {
    var isNumericPad: Bool { get { return contains(.numericPad) } }
    var isCommand:    Bool { get { return contains(.command) } }
    var isOption:     Bool { get { return contains(.option) } }
    var isShift:      Bool { get { return contains(.shift) } }
}


extension NSEvent {
    var input: String {
        get {
            if let result = charactersIgnoringModifiers {
                return result as String
            }

            return ""
        }
    }
}


extension NSColor {
    func darker(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent * 1.1, brightness: brightnessComponent / by, alpha: alphaComponent)
    }
}


extension NSBezierPath {
    public var cgPath: CGPath {
        let   path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)

        for i in 0 ..< self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)

            switch type {
            case .closePathBezierPathElement: path.closeSubpath()
            case .moveToBezierPathElement:    path.move    (to: CGPoint(x: points[0].x, y: points[0].y) )
            case .lineToBezierPathElement:    path.addLine (to: CGPoint(x: points[0].x, y: points[0].y) )
            case .curveToBezierPathElement:   path.addCurve(to: CGPoint(x: points[2].x, y: points[2].y),
                                                      control1: CGPoint(x: points[0].x, y: points[0].y),
                                                      control2: CGPoint(x: points[1].x, y: points[1].y) )
            }
        }

        return path
    }


    public convenience init(roundedRect rect: CGRect, cornerRadius: CGFloat) {
        self.init(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    }
}


extension NSView {
    var      zlayer:                CALayer { get { wantsLayer = true; return layer! } set { layer = newValue } }
    var recognizers: [NSGestureRecognizer]? { get { return gestureRecognizers } }


    func clear() { zlayer.backgroundColor = ZColor.clear.cgColor }
    func setNeedsDisplay() { needsDisplay = true }
    func setNeedsLayout () { needsLayout  = true }
    func insertSubview(_ view: ZView, belowSubview siblingSubview: ZView) { addSubview(view, positioned: .below, relativeTo: siblingSubview) }



    @discardableResult func createDragGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?) -> NSGestureRecognizer {
        let      gesture = NSPanGestureRecognizer(target: target, action: action)
        gesture.delegate = target

        addGestureRecognizer(gesture)

        return gesture
    }


    @discardableResult func createPointGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?, clicksRequired: Int) -> NSGestureRecognizer {
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


extension Zone {


    func hasZoneAbove(_ iAbove: Bool) -> Bool {
        if  let index = siblingIndex {
            return index != (iAbove ? 0 : (parentZone!.count - 1))
        }

        return false
    }
    
}


extension ZoneWidget {


    func rectForLine(to targetFrame: CGRect, kind: ZLineKind) -> CGRect {
        var frame = CGRect ()

        if  let     sourceDot = toggleDot.innerDot {
            let   sourceFrame = sourceDot.convert( sourceDot.bounds, to: self)
            let     thickness = CGFloat(gLineThickness)
            let     dotHeight = CGFloat(gDotHeight)
            let halfDotHeight = dotHeight / 2.0
            let thinThickness = thickness / 2.0
            let    targetMidY = targetFrame.midY
            let    sourceMidY = sourceFrame  .midY
            frame.origin   .x = sourceFrame  .midX

            switch kind {
            case .above:
                frame.origin   .y = sourceFrame.maxY - thinThickness
                frame.size.height = fabs( targetMidY + thinThickness - frame.minY)
            case .below:
                frame.origin   .y = targetFrame.minY + halfDotHeight
                frame.size.height = fabs( sourceMidY + thinThickness - frame.minY - halfDotHeight)
            case .straight:
                frame.origin   .y =       targetMidY - thinThickness / 8.0
                frame.origin   .x = sourceFrame.maxX
                frame.size.height =                    thinThickness / 4.0
            }

            frame.size     .width = fabs(targetFrame.minX - frame.minX)
        }
        
        return frame
    }


    func curvedPathFor(_ iRect: CGRect, iKind: ZLineKind) -> ZBezierPath {
        ZBezierPath(rect: iRect).setClip()

        let      dotHeight = CGFloat(gDotHeight)
        let   halfDotWidth = CGFloat(gDotWidth) / 2.0
        let  halfDotHeight = dotHeight / 2.0
        let        isAbove = iKind == .above
        var           rect = iRect

        if isAbove {
            rect.origin.y -= rect.height + halfDotHeight
        }

        rect.size   .width = rect.width  * 2.0 + halfDotWidth
        rect.size  .height = rect.height * 2.0 + (isAbove ? halfDotHeight : dotHeight)

        return ZBezierPath(ovalIn: rect)
    }
}
