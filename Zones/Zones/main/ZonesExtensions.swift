//
//  ZonesExtensions.swift
//  Zones
//
//  Created by Jonathan Sand on 1/31/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import Cocoa


enum ZArrowKey: CChar {
    case up    = -128
    case down
    case left
    case right
}


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
public typealias ZColorWell                 = NSColorWell
public typealias ZButtonCell                = NSButtonCell
public typealias ZBezierPath                = NSBezierPath
public typealias ZController                = NSViewController
public typealias ZEventFlags                = NSEventModifierFlags
public typealias ZSearchField               = NSSearchField
public typealias ZApplication               = NSApplication
public typealias ZTableCellView             = NSTableCellView
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
let   gBackspaceKey = "\u{8}"
let      gDeleteKey = "\u{7F}"
let       gSpaceKey = " "
let         gTabKey = "\t"


extension NSObject {
    var highlightHeightOffset: CGFloat { return -3.0 }
    func assignAsFirstResponder(_ responder: NSResponder?) {
        ZoneWindow.window?.makeFirstResponder(responder)
    }
}


extension String {
    var arrow: ZArrowKey? {
        if containsNonAscii {
            let character = utf8CString[2]

            for arrowKey in ZArrowKey.up.rawValue...ZArrowKey.right.rawValue {
                if arrowKey == character {
                    return ZArrowKey(rawValue: character)
                }
            }
        }

        return nil
    }


    var cgSize: CGSize {
        let size = NSSizeFromString(self)

        return CGSize(width: size.width, height: size.height)
    }
}


extension NSEvent {
    var key: String { return input.character(at: 0) }
}


extension NSApplication {
    func clearBadge() {
        dockTile.badgeLabel = ""
    }
}


extension NSEventModifierFlags {
    var isNumericPad: Bool { return contains(.numericPad) }
    var isControl:    Bool { return contains(.control) }
    var isCommand:    Bool { return contains(.command) }
    var isOption:     Bool { return contains(.option) }
    var isShift:      Bool { return contains(.shift) }
}


extension NSEvent {
    var input: String {
        if let result = charactersIgnoringModifiers {
            return result as String
        }

        return ""
    }
}


extension NSColor {
    func darker(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent * 1.1, brightness: brightnessComponent / by, alpha: alphaComponent)
    }

    func lighter(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent * 0.9, brightness: brightnessComponent * by, alpha: alphaComponent)
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
    var recognizers: [NSGestureRecognizer]? { return gestureRecognizers }


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


extension NSWindow {

    
    override open var acceptsFirstResponder: Bool { return true }


    override open func validateMenuItem(_ menuItem: ZMenuItem) -> Bool {
        enum ZMenuType: Int {
            case Grab  = 1
            case Paste = 2
            case Undo  = 3
            case Redo  = 4
            case All   = 5
            case Child = 6
            case Zone  = 7
        }

        var valid = !gEditingManager.isEditing
        let   tag = menuItem.tag

        if  tag <= 7, tag > 0, let type = ZMenuType(rawValue: tag) {
            if gEditingManager.isEditing && type != .Undo && type != .Redo {
                valid = [.All, .Zone, .Child].contains(type)
            } else {
                switch type {
                case .Child,
                     .Zone:  valid = true
                case .Undo:  valid = gEditingManager.undoManager.canUndo
                case .Redo:  valid = gEditingManager.undoManager.canRedo
                case .Grab:  valid = gSelectionManager.currentGrabs.count > 0
                case .Paste: valid = gSelectionManager       .pasteableZones.count > 0
                default:     valid = false
                }
            }
        }

        return valid
    }


    @IBAction func displayPreferences     (_ sender: Any?) { settingsController?.displayViewFor(id: .Preferences) }
    @IBAction func displayHelp            (_ sender: Any?) { settingsController?.displayViewFor(id: .Help) }
    @IBAction func printHere              (_ sender: Any?) { gEditingManager.printHere() }
    @IBAction func genericMenuHandler(_ iItem: ZMenuItem?) { gEditingManager.handleMenuItem(iItem) }
    @IBAction func copy              (_ iItem: ZMenuItem?) { gEditingManager.copyToPaste() }
    @IBAction func cut               (_ iItem: ZMenuItem?) { gEditingManager.delete() }
    @IBAction func delete            (_ iItem: ZMenuItem?) { gEditingManager.delete() }
    @IBAction func paste             (_ iItem: ZMenuItem?) { gEditingManager.paste() }
    @IBAction func toggleSearch      (_ iItem: ZMenuItem?) { gEditingManager.find() }
    @IBAction func undo              (_ iItem: ZMenuItem?) { gEditingManager.undoManager.undo() }
    @IBAction func redo              (_ iItem: ZMenuItem?) { gEditingManager.undoManager.redo() }
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
    var          text:         String? { get { return stringValue } set { stringValue = newValue! } }
    var textAlignment: NSTextAlignment { get { return alignment }   set { alignment = newValue } }
}


extension ZoneTextWidget {
    // override open var acceptsFirstResponder: Bool { return gOperationsManager.isReady }    // fix a bug where root zone is editing on launch


    func updateGUI() {
        widget.layoutTextField()
        widget.setNeedsDisplay()
    }


    override func controlTextDidChange(_ iNote: Notification) {
        prepareUndoForTextChange(undoManager) {
            self.controlTextDidChange(iNote)
        }

        updateGUI()
    }


    override func textDidEndEditing(_ notification: Notification) {
        resignFirstResponder()

        if  let        value = notification.userInfo?["NSTextMovement"] as? NSNumber {
            var key: String? = nil

            switch value.intValue {
            case NSTabTextMovement:     key = gTabKey
            case NSBacktabTextMovement: key = gSpaceKey
            default:                    return
            }

            dispatchAsyncInForeground { // execute on next cycle of runloop
                gEditingManager.handleKey(key, flags: ZEventFlags(), isWindow: true)
            }
        }
    }


    func selectAllText() {
        if text != nil, let editor = currentEditor() {
            gSelectionManager.deferEditingStateChange()
            select(withFrame: bounds, editor: editor, delegate: self, start: 0, length: text!.characters.count)
        }
    }


    func addMonitor() {
        monitor = ZEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { (event) -> ZEvent? in
            if self.isTextEditing, !event.modifierFlags.isNumericPad {
                gEditingManager.handleEvent(event, isWindow: false)
            }

            return event
        })
    }


    func removeMonitorAsync() {
        if let save = monitor {
            monitor = nil

            dispatchAsyncInForegroundAfter(0.001, closure: {
                ZEvent.removeMonitor(save)
            })
        }
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


    var dragHitFrame: CGRect {
        var hitRect = CGRect()

        if  let   view = gEditorView, let dot = dragDot.innerDot {
            let isHere = widgetZone == gHere
            let cFrame =     convert(childrenView.frame, to: view)
            let dFrame = dot.convert(        dot.bounds, to: view)
            let bottom =  (!isHere && widgetZone.hasZonesBelow) ? cFrame.minY : 0.0
            let    top = ((!isHere && widgetZone.hasZonesAbove) ? cFrame      : view.bounds).maxY
            let  right =                                                        view.bounds .maxX
            let   left =    isHere ? 0.0 : dFrame.minX - gGenericOffset.width
            hitRect    = CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
        }

        return hitRect
    }


    func lineRect(to targetFrame: CGRect, kind: ZLineKind?) -> CGRect {
        var frame = CGRect ()

        if  let     sourceDot = toggleDot.innerDot, kind != nil {
            let   sourceFrame = sourceDot.convert( sourceDot.bounds, to: self)
            let     thickness = CGFloat(gLineThickness)
            let     dotHeight = CGFloat(gDotHeight)
            let halfDotHeight = dotHeight / 2.0
            let thinThickness = thickness / 2.0
            let    targetMidY = targetFrame.midY
            let    sourceMidY = sourceFrame  .midY
            frame.origin   .x = sourceFrame  .midX

            switch kind! {
            case .above:
                frame.origin   .y = sourceFrame.maxY - halfDotHeight + thickness
                frame.size.height = fabs( targetMidY + thinThickness - frame.minY)
            case .below:
                frame.origin   .y = targetFrame.minY + halfDotHeight - thickness
                frame.size.height = fabs( sourceMidY + thinThickness - frame.minY - halfDotHeight)
            case .straight:
                frame.origin   .y =       targetMidY - thinThickness / 2.0
                frame.origin   .x = sourceFrame.maxX
                frame.size.height =                    thinThickness
            }

            frame.size     .width = fabs(targetFrame.minX - frame.minX)
        }
        
        return frame
    }


    func curvedPath(in iRect: CGRect, kind iKind: ZLineKind) -> ZBezierPath {
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
