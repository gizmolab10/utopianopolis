//
//  ZDesktopExtensions.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/31/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit
import AppKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif


enum ZArrowKey: Int8 {
    case up    = -128
    case down
    case left
    case right

	var key: String {
		var utf : [Int8] = [-17, -100, rawValue, 0]

		return String(cString: &utf)
	}
}

public typealias ZBox                        = NSBox
public typealias ZFont                       = NSFont
public typealias ZView                       = NSView
public typealias ZMenu                       = NSMenu
public typealias ZAlert                      = NSAlert
public typealias ZEvent                      = NSEvent
public typealias ZImage                      = NSImage
public typealias ZColor                      = NSColor
public typealias ZButton                     = NSButton
public typealias ZSlider                     = NSSlider
public typealias ZWindow                     = NSWindow
public typealias ZControl                    = NSControl
public typealias ZMenuItem                   = NSMenuItem
public typealias ZClipView                   = NSClipView
public typealias ZTextView                   = NSTextView
public typealias ZTextField                  = NSTextField
public typealias ZTableView                  = NSTableView
public typealias ZStackView                  = NSStackView
public typealias ZImageView                  = NSImageView
public typealias ZColorWell                  = NSColorWell
public typealias ZButtonCell                 = NSButtonCell
public typealias ZBezierPath                 = NSBezierPath
public typealias ZScrollView                 = NSScrollView
public typealias ZController                 = NSViewController
public typealias ZEventFlags                 = ZEvent.ModifierFlags
public typealias ZSearchField                = NSSearchField
public typealias ZApplication                = NSApplication
public typealias ZTableColumn                = NSTableColumn
public typealias ZTableRowView               = NSTableRowView
public typealias ZMenuDelegate               = NSMenuDelegate
public typealias ZTableCellView              = NSTableCellView
public typealias ZBitmapImageRep             = NSBitmapImageRep
public typealias ZWindowDelegate             = NSWindowDelegate
public typealias ZWindowController           = NSWindowController
public typealias ZSegmentedControl           = NSSegmentedControl
public typealias ZTextViewDelegate           = NSTextViewDelegate
public typealias ZTextFieldDelegate          = NSTextFieldDelegate
public typealias ZGestureRecognizer          = NSGestureRecognizer
public typealias ZProgressIndicator          = NSProgressIndicator
public typealias ZTableViewDelegate          = NSTableViewDelegate
public typealias ZTableViewDataSource        = NSTableViewDataSource
public typealias ZSearchFieldDelegate        = NSSearchFieldDelegate
public typealias ZApplicationDelegate        = NSApplicationDelegate
public typealias ZPanGestureRecognizer       = NSPanGestureRecognizer
public typealias ZClickGestureRecognizer     = NSClickGestureRecognizer
public typealias ZGestureRecognizerState     = NSGestureRecognizer.State
public typealias ZGestureRecognizerDelegate  = NSGestureRecognizerDelegate
public typealias ZEdgeSwipeGestureRecognizer = NSNull

let kVerticalWeight = CGFloat( 1)

var gIsPrinting: Bool {
    return NSPrintOperation.current != nil
}

protocol ZScrollDelegate : NSObjectProtocol {}

func isDuplicate(event: ZEvent? = nil, item: ZMenuItem? = nil) -> Bool {
    if  let e  = event {
        if  e == gCurrentEvent {
            return true
        } else {
            gCurrentEvent = e
        }
    }
    
    if  item != nil {
        return gCurrentEvent != nil && (gTimeSinceCurrentEvent < 0.4)
    }
    
    return false
}

// Helper function inserted by Swift 4.2 migrator.
func gConvertFromOptionalUserInterfaceItemIdentifier(_ input: NSUserInterfaceItemIdentifier?) -> String? {
    guard let input = input else { return nil }
    return input.rawValue
}

func gConvertToUserInterfaceItemIdentifier(_ string: String) -> NSUserInterfaceItemIdentifier {
	return NSUserInterfaceItemIdentifier(rawValue: string)
}

extension NSObject {
    func assignAsFirstResponder(_ responder: NSResponder?) {
        if  let window = gMainWindow,
            ![window, responder].contains(window.firstResponder) {
            window.makeFirstResponder(responder)
        }
	}
	
	func showTopLevelFunctions() {}
}

extension String {

	func heightForFont(_ font: ZFont, options: NSString.DrawingOptions = .usesDeviceMetrics) -> CGFloat { return sizeWithFont(font, options: options).height }
    func sizeWithFont (_ font: ZFont, options: NSString.DrawingOptions = .usesFontLeading) -> CGSize { return rectWithFont(font, options: options).size }

    func  rectWithFont(_ font: ZFont, options: NSString.DrawingOptions = .usesFontLeading) -> CGRect {
        return self.boundingRect(with: CGSize.big, options: options, attributes: [.font : font])
    }
    
    var cgPoint: CGPoint {
        let point = NSPointFromString(self)

        return CGPoint(x: point.x, y: point.y)
    }

    var cgSize: CGSize {
        let size = NSSizeFromString(self)
        
        return CGSize(width: size.width, height: size.height)
    }

    var cgRect: CGRect {
        let rect = NSRectFromString(self)
        
        return CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
    }

    var arrow: ZArrowKey? {
        if  containsNonAscii {
            let character = utf8CString[2]
            
            for arrowKey in ZArrowKey.up.rawValue...ZArrowKey.right.rawValue {
                if  arrowKey == character {
                    return ZArrowKey(rawValue: character)
                }
            }
        }
        
        return nil
    }

    func openAsURL() {
        let fileScheme = "file"
        let filePrefix = fileScheme + "://"
        let  urlString = (replacingOccurrences(of: kBackSlash, with: kEmpty).replacingOccurrences(of: kSpace, with: "%20") as NSString).expandingTildeInPath
        
        if  var url = NSURL(string: urlString) {
            if  urlString.character(at: 0) == "/" {
                url = NSURL(string: filePrefix + urlString)!
            }

            if  url.scheme != fileScheme {
                url.open()
            } else if let path = url.path {
                url = NSURL(fileURLWithPath: path)

                url.openAsFile()
            }
        }
    }
    
}

extension NSURL {
    
    var directoryURL: URL? {
        return nil
    }

    func open() {
        NSWorkspace.shared.open(self as URL)
    }

    func openAsFile() {
//        if !openSecurely() {
//            ZFiles.presentOpenPanel() { (iAny) in
//                if  let url = iAny as? NSURL {
//                    url.open()
//                } else if let panel = iAny as? NSPanel {
//                    if    let  name = self.lastPathComponent {
//                        panel.title = "Open \(name)"
//                    }
//                    
//                    panel.setDirectoryAndExtensionFor(self as URL)
//                }
//            }
//        }
    }

}

extension ZApplication {

    func clearBadge() {
        dockTile.badgeLabel = kEmpty
    }
    
    func showHideAbout() {
        for     window in windows {
			if  window.isKeyWindow,
				window.isKind(of: NSPanel.self) { // check if about box is visible
                window.close()

				return
            }
        }
        
        orderFrontStandardAboutPanel(nil)
    }
    
}

extension ZEventFlags {

	var isAnyMultiple:  Bool       { return  exactlySplayed || exactlySpecial || exactlyUnusual || exactlyAll }
	var isAny:          Bool       { return  isCommand ||  isOption ||  isControl }
	var exactlyAll:     Bool       { return  isCommand &&  isOption &&  isControl }
	var exactlySpecial: Bool       { return  isCommand &&  isOption && !isControl }
	var exactlySplayed: Bool       { return  isCommand && !isOption &&  isControl }
	var exactlyUnusual: Bool       { return !isCommand &&  isOption &&  isControl }
    var isNumericPad:   Bool       { return  contains(.numericPad) }
    var isControl:      Bool { get { return  contains(.control) } set { if newValue { insert(.control) } else { remove(.control) } } }
	var isCommand:      Bool { get { return  contains(.command) } set { if newValue { insert(.command) } else { remove(.command) } } }
    var isOption:       Bool { get { return  contains(.option)  } set { if newValue { insert(.option)  } else { remove(.option) } } }
    var isShift:        Bool { get { return  contains(.shift)   } set { if newValue { insert(.shift)   } else { remove(.shift) } } }

}

extension ZEvent {

	var arrow: ZArrowKey? { return key?.arrow }
    var input:    String? { return charactersIgnoringModifiers }

	var key: String? {
		if  let    i = input, i.length > 0 {
			return i.character(at: 0)
		}

		return nil
	}

}

extension ZColor {

	convenience init(string: String) {
		var r: CGFloat = 1
		var g: CGFloat = 1
		var b: CGFloat = 1
		var a: CGFloat = 1
		let parts = string.components(separatedBy: kCommaSeparator)
		for part in parts {
			let items = part.components(separatedBy: kColonSeparator)
			if  items.count > 1 {
				let key = items[0]
				let value = items[1]
				let f = CGFloat(Double(value) ?? 1)
				switch key {
					case "red":   r = f
					case "blue":  b = f
					case "green": g = f
					case "alpha": a = f
					default: break
				}
			}
		}

		self.init(red: r, green: g, blue: b, alpha: a)
	}

	var string: String? {
		if  let c = usingColorSpace(NSColorSpace.deviceRGB) {
			return "red:\(c.redComponent),blue:\(c.blueComponent),green:\(c.greenComponent),alpha:\(c.alphaComponent)"
		}

		return nil
	}

	var accountingForDarkMode: NSColor { return gIsDark ? inverted : self }

    func darker(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent * (by * 2), brightness: brightnessComponent / (by / 3), alpha: alphaComponent)
    }

    func lighter(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent / (by / 2), brightness: brightnessComponent * (by / 3), alpha: alphaComponent)
    }
    
    func lightish(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent,              brightness: brightnessComponent * by,         alpha: alphaComponent)
    }

    var inverted: ZColor {
        let b = max(0.0, min(1.0, 1.25 - brightnessComponent))
        let s = max(0.0, min(1.0, 1.45 - saturationComponent))
        
        return ZColor(calibratedHue: hueComponent, saturation: s, brightness: b, alpha: alphaComponent)
    }
    
}

extension CGRect {

	var centerTop:    CGPoint { return CGPoint(x: midX, y: minY) }
	var centerLeft:   CGPoint { return CGPoint(x: minX, y: midY) }
	var centerRight:  CGPoint { return CGPoint(x: maxX, y: midY) }
	var center:       CGPoint { return CGPoint(x: midX, y: midY) }
	var centerBottom: CGPoint { return CGPoint(x: midX, y: maxY) }
	var bottomRight:  CGPoint { return CGPoint(x: maxX, y: minY) }
	var bottomLeft:   CGPoint { return CGPoint(x: minX, y: minY) } // same as origin
	var topLeft:      CGPoint { return CGPoint(x: minX, y: maxY) }
	var extent:       CGPoint { return CGPoint(x: maxX, y: maxY) }

}

extension NSBezierPath {

	public var cgPath: CGPath {
        let   path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)

        for i in 0 ..< self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)

            switch type {
            case .closePath: path.closeSubpath()
            case .moveTo:    path.move    (to: CGPoint(x: points[0].x, y: points[0].y) )
            case .lineTo:    path.addLine (to: CGPoint(x: points[0].x, y: points[0].y) )
            case .curveTo:   path.addCurve(to: CGPoint(x: points[2].x, y: points[2].y),
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

extension ZTextView {

	func setText(_ text: Any) {
		let range = NSRange(location: 0, length: textStorage?.length ?? 0)

		guard let string = text as? NSMutableAttributedString else {
			insertText(text, replacementRange: range)

			return
		}

		insertText(string.string, replacementRange: range)
		textStorage?.removeAllAttributes()

		textStorage?.attributesAsString = string.attributesAsString
	}

	func rectForRange(_ range: NSRange) -> CGRect? {
		let rects = rectsForRange(range)

		if  rects.count > 0 {
			return rects[0]
		}

		return nil
	}

	func rectsForRange(_ range: NSRange) -> [CGRect] {
		var result = [CGRect]()

		if  let  m = layoutManager,
			let  c = textContainer {

			m.enumerateEnclosingRects(forGlyphRange: range, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: c) { (rect, flag) in
				result.append(rect.offsetBy(dx: 20.0, dy: 0.0))
			}
		}

		return result
	}

	@objc override func printView() { // ZTextView
		if  gProducts.hasEnabledSubscription {
			var view: NSView = self
			let    printInfo = NSPrintInfo.shared
			let pmPageFormat = PMPageFormat(printInfo.pmPageFormat())
			if  let    tView = view as? NSTextView {
				let    frame = CGRect(origin: .zero, size: CGSize(width: 6.5 * 72.0, height: 9.5 * 72.0))
				let    nView = NSTextView(frame: frame)
				view         = nView

				nView.insertText(tView.textStorage as Any, replacementRange: NSRange())
			}

			PMSetScale(pmPageFormat, 100.0)
			PMSetOrientation(pmPageFormat, PMOrientation(kPMPortrait), false)
			printInfo.updateFromPMPrintSettings()
			printInfo.updateFromPMPageFormat()
			NSPrintOperation(view: view, printInfo: printInfo).run()
		}
	}

}

extension CALayer {

	func removeAllSublayers() {
		if  let subs = sublayers {
			for sub in subs {
				sub.removeFromSuperlayer()
			}
		}
	}

}

extension ZView {
    var      zlayer:                CALayer { get { wantsLayer = true; return layer! } set { layer = newValue } }
    var recognizers: [NSGestureRecognizer]? { return gestureRecognizers }

    var gestureHandler: ZGesturesController? {
        get {
			if  let r = recognizers, r.count > 0 {
				return r[0].delegate as? ZGesturesController
			}

			return nil
		}
        set {
            clearGestures()

            if  let controller = newValue {
                controller.movementGesture = createDragGestureRecognizer (controller, action: #selector(controller.handleDragGesture))
                controller.clickGesture    = createPointGestureRecognizer(controller, action: #selector(controller.handleClickGesture), clicksRequired: 1)
            }
        }
    }

    func setNeedsDisplay() { if !gDeferringRedraw { needsDisplay = true } }
    func setNeedsLayout () { needsLayout  = true }
    func insertSubview(_ view: ZView, belowSubview siblingSubview: ZView) { addSubview(view, positioned: .below, relativeTo: siblingSubview) }

    func setShortestDimension(to: CGFloat) {
        if  frame.size.width  < frame.size.height {
            frame.size.width  = to
        } else {
            frame.size.height = to
        }
    }

    @discardableResult func createDragGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?) -> ZKeyPanGestureRecognizer {
        let                            gesture = ZKeyPanGestureRecognizer(target: target, action: action)
        gesture                      .delegate = target
        gesture               .delaysKeyEvents = false
        gesture.delaysPrimaryMouseButtonEvents = false

        addGestureRecognizer(gesture)

        return gesture
    }

    @discardableResult func createPointGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?, clicksRequired: Int) -> ZKeyClickGestureRecognizer {
        let                            gesture = ZKeyClickGestureRecognizer(target: target, action: action)
        gesture.numberOfClicksRequired         = clicksRequired
        gesture.delaysPrimaryMouseButtonEvents = false
        gesture.delegate                       = target

        addGestureRecognizer(gesture)

        return gesture
    }
    
    func scale(forHorizontal: Bool) -> Double {
		let     dividend = 7200.0 * (forHorizontal ? 8.5 : 11.0) // (inches) * 72 (dpi) * 100 (percent)
        let       length = Double(forHorizontal ? bounds.size.width : bounds.size.height)
        let        scale = dividend / length

        return scale
    }
    
    var scale: Double {
        let wScale = scale(forHorizontal: true)
        let hScale = scale(forHorizontal: false)

        return min(wScale, hScale)
    }

	@objc func printView() { // ZView
		if  gProducts.hasEnabledSubscription {
			let    printInfo = NSPrintInfo.shared
			let      isWider = bounds.size.width > bounds.size.height
			let  orientation = PMOrientation(isWider ? kPMLandscape : kPMPortrait)
			let pmPageFormat = PMPageFormat(printInfo.pmPageFormat())

			PMSetScale(pmPageFormat, 80.0)
			PMSetOrientation(pmPageFormat, orientation, false)
			printInfo.updateFromPMPrintSettings()
			printInfo.updateFromPMPageFormat()
			NSPrintOperation(view: self, printInfo: printInfo).run()
		}
	}

	func drawBox(in view: ZView, inset: CGFloat = 0, with color: ZColor) {
		convert(bounds, to: view).insetEquallyBy(inset).drawColoredRect(color)
	}

}

extension ZMapView {
    
    func updateMagnification(with event: ZEvent) {
        let     deltaY = event.deltaY
        let adjustment = exp2(deltaY / 100.0)
        gScaling      *= Double(adjustment)
    }

    override func scrollWheel(with event: ZEvent) {
        if  event.modifierFlags.isCommand {
            updateMagnification(with: event)
        } else {
            let     multiply = CGFloat(1.5 * gScaling)
            gScrollOffset.x += event.deltaX * multiply
            gScrollOffset.y += event.deltaY * multiply
        }
        
        gMapController?.layoutForCurrentScrollOffset()
    }

}

extension ZoneWindow {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        delegate              = self
        ZoneWindow.mainWindow = self
        contentMinSize        = kDefaultWindowRect.size // smallest size user to which can shrink window
        let              rect = gWindowRect
        
        setFrame(rect, display: true)
        
        observer = observe(\.effectiveAppearance) { _, _  in
            gSignal([.sAppearance])
        }
    }
    
}

extension ZWindow {

	@IBAction func displayPreferences(_ sender:      Any?) { gDetailsController?.view(for: .vPreferences)?.toggleAction(self) }
	@IBAction func displayHelp       (_ sender:      Any?) { openBrowserForFocusWebsite() }
	@IBAction func copy              (_ iItem: ZMenuItem?) { gSelecting.simplifiedGrabs.copyToPaste() }
	@IBAction func cut               (_ iItem: ZMenuItem?) { gMapEditor.delete() }
	@IBAction func delete            (_ iItem: ZMenuItem?) { gMapEditor.delete() }
	@IBAction func paste             (_ iItem: ZMenuItem?) { gMapEditor.paste() }
	@IBAction func toggleSearch      (_ iItem: ZMenuItem?) { gSearching.showSearch() }
	@IBAction func undo              (_ iItem: ZMenuItem?) { gMapEditor.undoManager.undo() }
	@IBAction func redo              (_ iItem: ZMenuItem?) { gMapEditor.undoManager.redo() }

	var keyPressed: Bool {
		let    e  = nextEvent(matching: .keyDown, until: Date(), inMode: .default, dequeue: false)

		return e != nil
	}

	var mouseMoved: Bool {
		let last = gLastLocation
		let  now = mouseLocationOutsideOfEventStream

		if  contentView?.frame.contains(now) ?? false {
			gLastLocation = now
		}

		return last != gLastLocation
	}

	var userIsActive: Bool {
		return isKeyWindow && (mouseMoved || keyPressed)
	}

}

extension ZButtonCell {
    override open var objectValue: Any? {
        get { return title }
        set { title = newValue as? String ?? kEmpty }
    }
}

extension ZButton {
    var isCircular: Bool {
        get { return true }
        set { bezelStyle = newValue ? .circular : .rounded }
    }

    var onHit: Selector? {
        get { return action }
        set { action = newValue; target = self } }
}

extension ZAlert {

    func showModal(closure: AlertStatusClosure? = nil) {
        closure?((runModal() == .alertFirstButtonReturn) ? ZAlertStatus.sYes : ZAlertStatus.sNo)
    }

}

extension ZAlerts {
    
    func openSystemPreferences() {
        if  let url = NSURL(string: "x-apple.systempreferences:com.apple.ids.service.com.apple.private.alloy.icloudpairing") {
            url.open()
        }
    }

	func showAlert(_ iMessage: String = "Warning", _ iExplain: String? = nil, _ iOkayTitle: String = "OK", _ iCancelTitle: String? = nil, _ iImage: ZImage? = nil, alertWidth width: CGFloat? = nil, _ closure: AlertStatusClosure? = nil) {
		alert(iMessage, iExplain, iOkayTitle, iCancelTitle, iImage, width) { alert, status in
            switch status {
            case .sShow:
                alert?.showModal { status in
                    let window = alert?.window
                    
                    gApplication.abortModal()
                    window?.orderOut(alert)
                    closure?(status)
                }
            default:
                closure?(status)
            }
        }
    }

	func alert(_ iMessage: String = "Warning", _ iExplain: String? = nil, _ iOKTitle: String = "OK", _ iCancelTitle: String? = nil, _ iImage: ZImage? = nil, _ width: CGFloat? = nil, _ closure: AlertClosure? = nil) {
        FOREGROUND(canBeDirect: true) {
            let             a = ZAlert()
            a    .messageText = iMessage
            a.informativeText = iExplain ?? kEmpty
            
            a.addButton(withTitle: iOKTitle)
            
            if  let cancel = iCancelTitle {
                a.addButton(withTitle: cancel)
            }
            
            if  let image = iImage {
                let size = image.size
                let frame = NSMakeRect(50, 50, size.width, size.height)
                a.accessoryView = NSImageView(image: image)
                a.accessoryView?.frame = frame
                a.layout()
            } else if let     w = width {
				let       frame = CGRect(x: 0.0, y: 0.0, width: w, height: 0.0)
				a.accessoryView = ZView(frame: frame)
				a.layout()
			}
            
            closure?(a, .sShow)
        }
    }
    
}

extension ZTextField {
    var          text:         String? { get { return stringValue } set { stringValue = newValue ?? kEmpty } }
    var textAlignment: NSTextAlignment { get { return alignment }   set {   alignment = newValue } }

    func enableUndo() {
        cell?.allowsUndo = true
    }

    func select(range: NSRange) {
        select(from: range.lowerBound, to: range.upperBound)
    }

    func select(from: Int, to: Int) {
        if  let editor = currentEditor() {
            select(withFrame: bounds, editor: editor, delegate: self, start: from, length: to - from)
        }
    }

    func selectFromStart(toEnd: Bool = false) {
        if  let t = text {
            select(from: 0, to: toEnd ? t.length : 0)
            gTextEditor.clearOffset()
        }
    }
    

    func deselectAllText() {
        selectFromStart()
    }
    
    func selectAllText() {
        gTextEditor.deferEditingStateChange()
        selectFromStart(toEnd: true)
    }
    
}

extension ZoneTextWidget {
    // override open var acceptsFirstResponder: Bool { return gBatch.isReady }    // fix a bug where root zone is editing on launch
    override var acceptsFirstResponder : Bool  { return widgetZone?.userCanWrite ?? false }

    var isFirstResponder : Bool {
        if  let    first = window?.firstResponder {
            return first == currentEditor()
        }

        return false
    }

    override func textDidChange(_ iNote: Notification) {
        gTextEditor.prepareUndoForTextChange(undoManager) {
            self.textDidChange(iNote)
        }

		updateSize()

        if  text?.contains(kHalfLineOfDashes + " - ") ?? false {
            widgetZone?.zoneName = kLineOfDashes

            gTextEditor.updateText(inZone: widgetZone)
            gTextEditor.stopCurrentEdit()
        } else {
            updateGUI()
        }
    }

	override func textDidEndEditing(_ notification: Notification) {
		if !gIsEditingStateChanging,
			gIsEditIdeaMode,
			let       number = notification.userInfo?["NSTextMovement"] as? NSNumber {
            let        value = number.intValue
			let        flags = gModifierFlags
			let      isShift = flags.isShift
            var key: String?

            gTextEditor.stopCurrentEdit(forceCapture: isShift)

            switch value {
            case NSBacktabTextMovement: key = kSpace
            case NSTabTextMovement:     key = kTab
            case NSReturnTextMovement:  return
            default:                    break
            }

            FOREGROUND { // execute on next cycle of runloop
                gMainWindow?.handleKey(key, flags: flags)
            }
        }
    }

}

extension ZTextEditor {
    
    func fullResign()  { assignAsFirstResponder (nil) }
	
	func showSpecialCharactersPopup() {
		let  menu = ZMenu.specialCharactersPopup(target: self, action: #selector(handleSpecialsPopupMenu(_:)))
		let point = CGPoint(x: -165.0, y: -60.0)

		menu.popUp(positioning: nil, at: point, in: gTextEditor.currentTextWidget)
	}

	@objc func handleSpecialsPopupMenu(_ iItem: ZMenuItem) {
		#if os(OSX)
		if  let  type = ZSpecialCharactersMenuType(rawValue: iItem.keyEquivalent),
			let range = selectedRanges[0] as? NSRange,
			type     != .eCancel {
			let  text = type.text

			insertText(text, replacementRange: range)
		}
		#endif
	}

    override func doCommand(by selector: Selector) {
        switch selector {
        case #selector(insertNewline):       stopCurrentEdit()
        case #selector(insertTab):           if currentEdit?.adequatelyPaused ?? true { gSelecting.rootMostMoveable?.addNext() } // stupid OSX issues tab twice (to create the new idea, then once MORE
		case #selector(cancelOperation(_:)): if gWaitingForSearchEntry || gSearchResultsVisible { gSearching.exitSearchMode() }
        default:                             super.doCommand(by: selector)
        }
    }
	
	@discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags) -> Bool {   // false means key not handled
		if  var        key = iKey {
			let        ANY = flags.isAny
			let editedZone = currentTextWidget?.widgetZone
			let      arrow = key.arrow

			if  key       != key.lowercased() {
				key        = key.lowercased()
			}

			if  let      a = arrow {
				gTextEditor.handleArrow(a, flags: flags)
			} else if ANY {
				switch key {
					case "i": showSpecialCharactersPopup()
					case "?": gHelpController?.show(flags: flags)
					case "-": return editedZone?.convertToFromLine() ?? false // false means key not handled
					default:  return false
				}
			} else if "|<>[]{}()\'\"".contains(key) {
				return        editedZone?.surround(by: key) ?? false
			} else {
				switch key {
					case "-":     return editedZone?.convertToFromLine() ?? false
					case kReturn: stopCurrentEdit()
					case kEscape: cancel()
					default:      return false // false means key not handled
				}
			}
		}

		return true
	}

    func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
		if gIsHelpFrontmost { return }

        switch arrow {
        case .up,
             .down: moveUp(arrow == .up, stopEdit: !flags.isOption)
        case .left:
            if  atStart {
                moveOut(true)
            } else {
                clearOffset()
                handleArrow(arrow, with: flags)
            }
        case .right:
            if  atEnd {
                moveOut(false)
            } else {
                clearOffset()
				handleArrow(arrow, with: flags)
            }
        }
    }

}

extension ZMenu {

	static func handleMenu() {}

	static func specialCharactersPopup(target: AnyObject, action: Selector) -> ZMenu {
		let menu = ZMenu(title: "add a special character")

		for type in ZSpecialCharactersMenuType.activeTypes {
			menu.addItem(specialsItem(type: type, target: target, action: action))
		}

		menu.addItem(ZMenuItem.separator())
		menu.addItem(specialsItem(type: .eCancel, target: target, action: action))

		return menu
	}

	static func specialsItem(type: ZSpecialCharactersMenuType, target: AnyObject, action: Selector) -> ZMenuItem {
		let  	  item = ZMenuItem(title: type.title, action: action, keyEquivalent: type.rawValue)
		item.isEnabled = true
		item.target    = target

		if  type != .eCancel {
			item.keyEquivalentModifierMask = ZEventFlags(rawValue: 0)
		}

		return item
	}

	static func reorderPopup(target: AnyObject, action: Selector) -> ZMenu {
		let menu = ZMenu(title: "reorder")

		for type in ZReorderMenuType.activeTypes {
			menu.addItem(reorderingItem(type: type, target: target, action: action))

			if  type != .eReversed {
				menu.addItem(reorderingItem(type: type, target: target, action: action, flagged: true))
			}

			menu.addItem(.separator())
		}

		return menu
	}

	static func reorderingItem(type: ZReorderMenuType, target: AnyObject, action: Selector, flagged: Bool = false) -> ZMenuItem {
		let                      title = flagged ? "\(type.title) reversed" : type.title
		let                       item = ZMenuItem(title: title, action: action, keyEquivalent: type.rawValue)
		item.keyEquivalentModifierMask = flagged ? ZEventFlags.shift : ZEventFlags(rawValue: 0)
		item                   .target = target
		item                .isEnabled = true

		return item
	}

	static func traitsPopup(target: AnyObject, action: Selector) -> ZMenu {
		let menu = ZMenu(title: "traits")

		for type in ZTraitType.activeTypes {
			menu.addItem(traitsItem(type: type, target: target, action: action))
		}

		return menu
	}

	static func traitsItem(type: ZTraitType, target: AnyObject, action: Selector) -> ZMenuItem {
		let                      title = type.title ?? ""
		let                       item = ZMenuItem(title: title, action: action, keyEquivalent: type.rawValue)
		item.keyEquivalentModifierMask = ZEventFlags(rawValue: 0)
		item                   .target = target
		item                .isEnabled = true

		return item
	}

	static func refetchPopup(target: AnyObject, action: Selector) -> ZMenu {
		let menu = ZMenu(title: "refetch")

		for type in ZRefetchMenuType.activeTypes {
			menu.addItem(refetchingItem(type: type, target: target, action: action))
		}

		return menu
	}

	static func refetchingItem(type: ZRefetchMenuType, target: AnyObject, action: Selector) -> ZMenuItem {
		let                       item = ZMenuItem(title: type.title, action: action, keyEquivalent: type.rawValue)
		item.keyEquivalentModifierMask = ZEvent.ModifierFlags(rawValue: 0)
		item                   .target = target
		item                .isEnabled = true

		return item
	}

}

extension NSText {
	
	func handleArrow(_ arrow: ZArrowKey, with flags: ZEventFlags) {
		let COMMAND = flags.isCommand
		let  OPTION = flags.isOption
		let   SHIFT = flags.isShift
		
		switch arrow {
		case .up:    moveToBeginningOfLine(self)
		case .down:  moveToEndOfLine(self)
		case .right:
			if         COMMAND && !SHIFT {
				moveToEndOfLine(self)
			} else if  COMMAND &&  SHIFT {
				moveToEndOfLineAndModifySelection(self)
			} else if  OPTION  &&  SHIFT {
				moveWordRightAndModifySelection(self)
			} else if !OPTION  &&  SHIFT {
				moveRightAndModifySelection(self)
			} else if  OPTION  && !SHIFT {
				moveWordRight(self)
			} else {
				moveRight(self)
			}
			
		case .left:
			if         COMMAND && !SHIFT {
				moveToBeginningOfLine(self)
			} else if  COMMAND &&  SHIFT {
				moveToBeginningOfLineAndModifySelection(self)
			} else if  OPTION  &&  SHIFT {
				moveWordLeftAndModifySelection(self)
			} else if !OPTION  &&  SHIFT {
				moveLeftAndModifySelection(self)
			} else if  OPTION  && !SHIFT {
				moveWordLeft(self)
			} else {
				moveLeft(self)
			}
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

public extension ZImage {

	var  png: Data? { return tiffRepresentation?.bitmap?.png }
	var jpeg: Data? { return tiffRepresentation?.bitmap?.jpeg }

	func oldResizedTo(_ newSize: CGSize) -> ZImage {
		let newImage = ZImage(size: newSize)
		let fromRect = CGRect(origin: CGPoint(), size: size)
		let   inRect = CGRect(origin: CGPoint(), size: newSize)

		newImage.lockFocus()
		draw(in: inRect, from: fromRect, operation: .copy, fraction: CGFloat(1))
		newImage.unlockFocus()

		return newImage
	}

	func resizedTo(_ newSize: NSSize) -> ZImage? {
		if  let bitmapRep = NSBitmapImageRep(
				bitmapDataPlanes      : nil,
				pixelsWide            : Int(newSize.width),
				pixelsHigh            : Int(newSize.height),
				bitsPerSample         : 8,
				samplesPerPixel       : 4,
				hasAlpha              : true,
				isPlanar              : false,
				colorSpaceName        : .calibratedRGB,
				bytesPerRow           : 0,
				bitsPerPixel          : 0 ) {
			NSGraphicsContext.saveGraphicsState()

			let              newImage = ZImage(size: newSize)
			let               newRect = CGRect(origin: CGPoint(), size: newSize)
			bitmapRep           .size = newSize
			NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

			draw(in: newRect, from: .zero, operation: .copy, fraction: 1.0)
			NSGraphicsContext.restoreGraphicsState()
			newImage.addRepresentation(bitmapRep)

			return newImage
		}

		return nil
	}

    func imageRotatedByDegrees(_ degrees: CGFloat) -> ZImage {
        var imageBounds = NSZeroRect ; imageBounds.size = self.size
        let pathBounds = NSBezierPath(rect: imageBounds)
        var transform = NSAffineTransform()
		let rotatedBounds:CGRect = NSMakeRect(NSZeroPoint.x, NSZeroPoint.y , self.size.width, self.size.height )
		let rotatedImage = NSImage(size: rotatedBounds.size)

		//Center the image within the rotated bounds
		imageBounds.origin.x = NSMidX(rotatedBounds) - (NSWidth(imageBounds) / 2)
		imageBounds.origin.y = NSMidY(rotatedBounds) - (NSHeight(imageBounds) / 2)

		transform.rotate(byDegrees: degrees)
        pathBounds.transform(using: transform as AffineTransform)

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
        draw(in: imageBounds, from: NSZeroRect, operation: .copy, fraction: 1.0)
        rotatedImage.unlockFocus()

        return rotatedImage
    }

}

extension ZBitmapImageRep {
	var  png: Data? { representation(using: .png,  properties: [:]) }
	var jpeg: Data? { representation(using: .jpeg, properties: [:]) }
}

extension Data {
	var bitmap: ZBitmapImageRep? { ZBitmapImageRep(data: self) }
}

extension ZFiles {

    func showInFinder() {
        (filesURL as NSURL).open()
    }
    
    class func presentOpenPanel(_ callback: AnyClosure? = nil) {
        if  let  window = gApplication.mainWindow {
            let   panel = NSOpenPanel()

            callback?(panel)

            panel.resolvesAliases               = true
            panel.canChooseDirectories          = false
            panel.canResolveUbiquitousConflicts = false
            panel.canDownloadUbiquitousContents = false
            
            panel.beginSheetModal(for: window) { (result) in
                if  result == NSApplication.ModalResponse.OK,
                    panel.urls.count > 0 {
                    let url = panel.urls[0]
                    
                    callback?(url)
                }
            }
        }
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

extension ZoneLine {

	func lineRect(for kind: ZLineCurve?) -> CGRect {
		switch mode {
		case .linearMode:   return   linearLineRect(for: kind)
		case .circularMode: return circularLineRect()
		}
	}

	func circularLineRect() -> CGRect {
		if  let origin = revealDot?.absoluteFrame.center,
			let center = dragDot?.absoluteFrame.center {
			let   size = CGSize(center - origin).absSize
			return CGRect(origin: origin, size: size)
		}

		return .zero
	}

    func linearLineRect(for kind: ZLineCurve?) -> CGRect {
		var                 rect = CGRect.zero
        if  kind                != nil,
			let      sourceFrame = revealDot?.absoluteFrame,
			let      targetFrame = dragDot?.absoluteFrame {
            rect.origin       .x = sourceFrame    .midX
			rect.size     .width = abs(targetFrame.midX - sourceFrame.midX) + 2.0
			let            delta = CGFloat(4)
			let       smallDelta = CGFloat(1)
			let        thickness = CGFloat(gLineThickness)

            switch kind! {
            case .above:
				rect.origin   .y =     sourceFrame.midY              - delta
				rect.size.height = abs(targetFrame.midY - rect.minY)
            case .below:
				rect.origin   .y =     targetFrame.midY              - smallDelta
				rect.size.height = abs(sourceFrame.midY - rect.minY) - delta
            case .straight:
				rect.origin   .y =     sourceFrame.midY              - smallDelta
                rect.size.height = thickness
            }
        }
        
        return rect
    }

    func curvedLinePath(in iRect: CGRect, kind: ZLineCurve) -> ZBezierPath {
        ZBezierPath(rect: iRect).setClip()

        let      dotHeight = CGFloat(gDotHeight)
        let   halfDotWidth = CGFloat(gDotWidth) / 2
        let  halfDotHeight = dotHeight / 2
        let        isAbove = kind == .above
        var           rect = iRect

        if  isAbove {
            rect.origin.y -= rect.height + halfDotHeight
        }

        rect.size   .width = rect.width  * 2 + halfDotWidth
        rect.size  .height = rect.height * 2 + (isAbove ? halfDotHeight : dotHeight)

        return ZBezierPath(ovalIn: rect)
    }

}

extension ZOnboarding {
    
    func getMAC() {
        if  let   iterator = findEthernetInterfaces() {
            if  let  array = getMACAddress(iterator) {
                let string = array.map( { String(format:"%02x", $0) } ).joined(separator: kColonSeparator)
                macAddress = string
            }
            
            IOObjectRelease(iterator)
        }
    }

    func findEthernetInterfaces() -> io_iterator_t? {
        
        let matchingDict = IOServiceMatching("IOEthernetInterface") as NSMutableDictionary
        matchingDict["IOPropertyMatch"] = [ "IOPrimaryInterface" : true]
        
        var matchingServices : io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &matchingServices) != KERN_SUCCESS {
            return nil
        }
        
        return matchingServices
    }

    func getMACAddress(_ iterator : io_iterator_t) -> [UInt8]? {
        var     address  : [UInt8]?
        while true {
			var service  : io_object_t = 0
			let next     = IOIteratorNext(iterator)
			if  next    != 0,
				IORegistryEntryGetParentEntry(next, "IOService", &service) == KERN_SUCCESS {
                let  ioData = IORegistryEntryCreateCFProperty(service, "IOMACAddress" as CFString, kCFAllocatorDefault, 0)

				IOObjectRelease(service)

				if  let data = ioData?.takeRetainedValue() as? NSData {
					address  = [0, 0, 0, 0, 0, 0]
					data.getBytes(&address!, length: address!.count)
				}

				break
			}
            
            IOObjectRelease(next)

			if  next == 0 {
				break
			}
        }
        
        return address
    }

}
