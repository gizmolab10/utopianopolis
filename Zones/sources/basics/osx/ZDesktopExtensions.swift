//
//  ZDesktopExtensions.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/31/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit
import SnapKit

#if os(OSX)
import AppKit
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
public typealias ZEventType                  = ZEvent.EventType
public typealias ZButtonCell                 = NSButtonCell
public typealias ZBezierPath                 = NSBezierPath
public typealias ZScrollView                 = NSScrollView
public typealias ZController                 = NSViewController
public typealias ZToolTipTag                 = ZView.ToolTipTag
public typealias ZEventFlags                 = ZEvent.ModifierFlags
public typealias ZSearchField                = NSSearchField
public typealias ZTableColumn                = NSTableColumn
public typealias ZTableRowView               = NSTableRowView
public typealias ZMenuDelegate               = NSMenuDelegate
public typealias ZTableCellView              = NSTableCellView
public typealias ZBitmapImageRep             = NSBitmapImageRep
public typealias ZWindowDelegate             = NSWindowDelegate
public typealias ZFontDescriptor             = NSFontDescriptor
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
public typealias ZClickGestureRecognizer     = NSClickGestureRecognizer
public typealias ZGestureRecognizerState     = NSGestureRecognizer.State
public typealias ZGestureRecognizerDelegate  = NSGestureRecognizerDelegate
public typealias ZEdgeSwipeGestureRecognizer = NSNull

let kVerticalWeight      = CGFloat(1)
var gIsPrinting          = false
var gFavoritesAreVisible : Bool { return gDetailsViewIsVisible(for: .vFavorites) }

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

func gPresentOpenPanel(_ callback: AnyClosure? = nil) {
	gMainController?.showAppIsBusy(true)

	if  let  window = gApplication?.mainWindow {
		let   panel = NSOpenPanel()

		callback?(panel)

		panel.resolvesAliases               = true
		panel.canChooseDirectories          = false
		panel.canResolveUbiquitousConflicts = false
		panel.canDownloadUbiquitousContents = false

		panel.beginSheetModal(for: window) { result in
			if  result          == .OK,
				panel.urls.count > 0 {
				let          url = panel.urls[0]

				callback?(url)
				gMainController?.showAppIsBusy(false)
			}
		}
	}
}

func gPresentOpenPanel(type: ZExportType, _ callback: AnyClosure? = nil) {
	gPresentOpenPanel() { iAny in
		if  let   panel = iAny as? NSOpenPanel {
			let  suffix = ZExportType.eSeriously.rawValue
			panel.title = "Import as \(suffix)"

			panel.allowedFileTypes = [suffix]
		} else {
			callback?(iAny)
		}
	}
}

func gPresentSavePanel(name iName: String?, suffix: String, _ callback: URLClosure? = nil) {
	if  let                      window = gApplication?.mainWindow {
		let                       panel = NSSavePanel()
		panel                  .message = "Export a \(suffix) file"
		if  let                    name = iName {
			panel .nameFieldStringValue = name + kPeriod + suffix
		}

		panel.beginSheetModal(for: window) { result in
			if  result                 == .OK,
				let fileURL = panel.url {
				gIsExportingToAFile     = true

				gInBackgroundWhileShowingBusy {
					callback?(fileURL)

					gIsExportingToAFile = false
				}
			}
		}
	}
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
		let r = (responder == nil) ? "nil" : "\(responder!)"
		printDebug(.dEdit, " WINDOW  " + r)

		gMainWindow?.makeFirstResponder(responder)
	}
	
	func showTopLevelFunctions() {}

}

extension NSIndexSet {

	var string : String {
		var result = ""
		var separator = ""
		enumerate { (index, _) in
			result = result + separator + "\(index)"
			separator = ", "
		}

		return "(" + result + ")"
	}
}

extension String {

	func widthForFont  (_ font: ZFont) -> CGFloat { return sizeWithFont(font).width + 4.0 }
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
        if  containsNoAscii {
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

		if  var url = URL(string: urlString) {
			if  urlString.character(at: 0) == kSlash {
				url = URL(string: filePrefix + urlString)!
			}

			if  url.scheme != fileScheme {
				url.open()
			} else {
				url = URL(fileURLWithPath: url.path)

				url.openAsFile()
			}
		}
	}
 
}

extension URL {
    
    var directoryURL: URL? {
        return nil
    }

    func open() {
        NSWorkspace.shared.open(self as URL)
    }

    func openAsFile() {
//        if !openSecurely() {
//            gPresentOpenPanel() { (iAny) in
//                if  let url = iAny as? URL {
//                    url.open()
//                } else if let panel = iAny as? NSPanel {
//                    if    let  name = lastPathComponent {
//                        panel.title = "Open \(name)"
//                    }
//                    
//                    panel.setDirectoryAndExtensionFor(self as URL)
//                }
//            }
//        }
    }

}

extension ZEventFlags {

	var exactlyOption:       Bool       { return !isAnyMultiple  &&  hasOption }
	var exactlyCommand:      Bool       { return !isAnyMultiple  &&  hasCommand }
	var exactlyControl:      Bool       { return !isAnyMultiple  &&  hasControl }
	var isAnyMultiple:       Bool       { return  exactlySplayed ||  exactlySpecial || exactlyOtherSpecial || exactlyAll }
	var isAny:               Bool       { return  hasCommand     ||  hasOption      ||  hasControl }
	var exactlyAll:          Bool       { return  hasCommand     &&  hasOption      &&  hasControl }
	var exactlySpecial:      Bool       { return  hasCommand     &&  hasOption      && !hasControl }
	var exactlySplayed:      Bool       { return  hasCommand     && !hasOption      &&  hasControl }
	var exactlyOtherSpecial: Bool       { return !hasCommand     &&  hasOption      &&  hasControl }
    var hasNumericPad:       Bool { get { return  contains(.numericPad) } set { if newValue { insert(.numericPad) } else { remove(.numericPad) } } }
	var hasControl:          Bool { get { return  contains(.control)    } set { if newValue { insert(.control)    } else { remove(.control) } } }
	var hasCommand:          Bool { get { return  contains(.command)    } set { if newValue { insert(.command)    } else { remove(.command) } } }
    var hasOption:           Bool { get { return  contains(.option)     } set { if newValue { insert(.option)     } else { remove(.option) } } }
    var hasShift:            Bool { get { return  contains(.shift)      } set { if newValue { insert(.shift)      } else { remove(.shift) } } }

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

	func locationRect(in view: ZView) -> CGRect {
		let  point = locationInWindow
		let origin = view.convert(point, from: nil)

		return CGRect(origin: origin, size: CGSize(width: 1.0, height: 1.0))
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

	var accountingForDarkMode: NSColor { return gIsDark ? invertedColor : self }

    func darker(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent * (by * 2), brightness: brightnessComponent / (by / 3), alpha: alphaComponent)
    }

    func lighter(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent / (by / 2), brightness: brightnessComponent * (by / 3), alpha: alphaComponent)
    }
    
    func lightish(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent,              brightness: brightnessComponent * by,         alpha: alphaComponent)
    }

    var invertedColor: ZColor {
        let b = max(.zero, min(1.0, 1.25 - brightnessComponent))
        let s = max(.zero, min(1.0, 1.45 - saturationComponent))
        
        return ZColor(calibratedHue: hueComponent, saturation: s, brightness: b, alpha: alphaComponent)
    }

	var invertedBlackAndWhite: ZColor {
		if  brightnessComponent < 0.5 {
			return kWhiteColor
		}

		return kBlackColor
	}

}

extension CGRect {

	var centerTop:    CGPoint { return CGPoint(x: midX, y: minY) }
	var centerLeft:   CGPoint { return CGPoint(x: minX, y: midY) }
	var centerRight:  CGPoint { return CGPoint(x: maxX, y: midY) }
	var center:       CGPoint { return CGPoint(x: midX, y: midY) }
	var centerBottom: CGPoint { return CGPoint(x: midX, y: maxY) }
	var bottomRight:  CGPoint { return CGPoint(x: maxX, y: maxY) }
	var bottomLeft:   CGPoint { return origin }
	var topLeft:      CGPoint { return CGPoint(x: minX, y: minY) }
	var topRight:     CGPoint { return extent }
	var extent:       CGPoint { return CGPoint(x: maxX, y: minY) }

}

extension NSBezierPath {

	public var cgPath: CGPath {
        let   path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)

        for i in 0 ..< elementCount {
            let type = element(at: i, associatedPoints: &points)

            switch type {
            case .closePath: path.closeSubpath()
            case .moveTo:    path.move    (to: CGPoint(x: points[0].x, y: points[0].y) )
            case .lineTo:    path.addLine (to: CGPoint(x: points[0].x, y: points[0].y) )
            case .curveTo:   path.addCurve(to: CGPoint(x: points[2].x, y: points[2].y),
                                                      control1: CGPoint(x: points[0].x, y: points[0].y),
                                                      control2: CGPoint(x: points[1].x, y: points[1].y) )
			@unknown default:
				fatalError()
			}
        }

        return path
    }

    public convenience init(roundedRect rect: CGRect, cornerRadius: CGFloat) {
        self.init(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    }

}

extension ZEssayView {

	func setText(_ text: Any) {
		let            range = NSRange(location: 0, length: textStorage?.length ?? 0)
		guard let attributed = text as? NSMutableAttributedString else {
			insertText(text, replacementRange: range)

			return
		}

		insertText(attributed.string, replacementRange: range)
		textStorage?.removeAllAttributes()

		textStorage?.attributesAsString = attributed.attributesAsString
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
				result.append(rect.offsetBy(dx: 20.0, dy: .zero))
			}
		}

		return result
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

	@objc func setNeedsDisplay() { if !gDeferringRedraw { needsDisplay = true } }
    func setNeedsLayout () { needsLayout  = true }
    func insertSubview(_ view: ZView, belowSubview siblingSubview: ZView) { addSubview(view, positioned: .below, relativeTo: siblingSubview) }

    func setShortestDimension(to: CGFloat) {
        if  frame.size.width  < frame.size.height {
            frame.size.width  = to
        } else {
            frame.size.height = to
        }
    }

    @discardableResult func createDragGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?) -> ZPanGestureRecognizer {
        let                            gesture = ZPanGestureRecognizer(target: target, action: action)
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

	func drawBox(in view: ZView, inset: CGFloat = 0, with color: ZColor) {
		convert(bounds, to: view).insetEquallyBy(inset).drawColoredRect(color)
	}

	func rearrangeInspectorTools() {

		// workaround bug in OS 10.12
		// discarded by display() arrrgh!!!!!!

		var             x = CGFloat(7.0)
		for tool in subviews {
			var      rect = tool.frame
			rect          = CGRect(origin: CGPoint(x: x, y: rect.minY), size: rect.size)
			x             = rect.maxX + 3.0
			tool   .frame = rect
		}
	}

	func relayoutInspectorTools() {

		// another workaround for bug in OS 10.12

		var x = 7.0

		for tool in subviews {
			let y = tool.isHidden ? -3.0 : -8.0
			tool.removeConstraints(tool.constraints)
			tool.snp.makeConstraints { make in
				make.left  .equalToSuperview().offset(x)
				make.bottom.equalToSuperview().offset(y)
			}

			x += 3.0 + Double(tool.bounds.width)
			tool.isHidden = false
		}
	}

}

extension ZMapView {
    
    func updateMagnification(with event: ZEvent) {
        let     deltaY = event.deltaY
        let adjustment = exp2(deltaY / 100.0)
        gScaling      *= Double(adjustment)
    }

    override func scrollWheel(with event: ZEvent) {
        if  event.modifierFlags.hasCommand {
            updateMagnification(with: event)
        } else {
            let     multiply = CGFloat(1.5 * gScaling)
            gMapOffset.x += event.deltaX * multiply
            gMapOffset.y += event.deltaY * multiply
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

	@IBAction func displayPreferences(_ sender:      Any?) { gDetailsController?.displayPreferences() }
	@IBAction func displayHelp       (_ sender:      Any?) { openBrowserForSeriouslyWebsite() }
	@IBAction func copy              (_ iItem: ZMenuItem?) { gSelecting.simplifiedGrabs.copyToPaste() }
	@IBAction func cut               (_ iItem: ZMenuItem?) { gMapEditor.delete() }
	@IBAction func delete            (_ iItem: ZMenuItem?) { gMapEditor.delete() }
	@IBAction func paste             (_ iItem: ZMenuItem?) { gMapEditor.paste() }
	@IBAction func toggleSearch      (_ iItem: ZMenuItem?) { gSearching.showSearch() }
	@IBAction func undo              (_ iItem: ZMenuItem?) { gMapEditor.undoManager.undo() }
	@IBAction func redo              (_ iItem: ZMenuItem?) { gMapEditor.undoManager.redo() }

	var userIsActive : Bool { return isKeyWindow && currentEvent != nil }
	var   keyPressed : Bool { return nextEvent(matching: .keyDown, until: Date(), inMode: .default, dequeue: false) != nil }

	var mouseMoved: Bool {
		let last = gLastLocation
		let  now = mouseLocationOutsideOfEventStream

		if  contentView?.frame.contains(now) ?? false {
			gLastLocation = now
		}

		return last != gLastLocation
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

	var width: CGFloat? {
		if  image != nil {
			return 9.0
		} else if title.length > 0 {
			let range = NSRange(location: 0, length: title.length)
			let  rect = title.rect(using: font!, for: range, atStart: true)

			return rect.width
		}

		return nil
	}

}

extension ZAlert {

    func showModal(closure: AlertStatusClosure? = nil) {
        closure?((runModal() == .alertFirstButtonReturn) ? .sYes : .sNo)
    }

}

extension ZAlerts {
    
    func openSystemPreferences() {
        URL(string: "x-apple.systempreferences:com.apple.ids.service.com.apple.private.alloy.icloudpairing")?.open()
    }
	
	func inform(_ message: String = "Warning", _ information: String? = nil) -> ZAlert {
		let             a = ZAlert()
		a    .messageText = message
		a.informativeText = information ?? kEmpty
		a     .alertStyle = .informational

		return a
	}

	func showAlert(_ message: String = "Warning", _ information: String? = nil, _ iOkayTitle: String = "OK", _ iCancelTitle: String? = nil, _ iImage: ZImage? = nil, alertWidth width: CGFloat? = nil, _ closure: AlertStatusClosure? = nil) {
		alertWithClosure(message, information, iOkayTitle, iCancelTitle, iImage, width) { iAlert, status in
            switch status {
            case .sShow:
					iAlert?.showModal { status in
                    let window = iAlert?.window
                    
                    gApplication?.abortModal()
                    window?.orderOut(iAlert)
                    closure?(status)
                }
            default:
                closure?(status)
            }
        }
    }

	func alertWithClosure(_ message: String = "Warning", _ information: String? = nil, _ iOKTitle: String = "OK", _ iCancelTitle: String? = nil, _ iImage: ZImage? = nil, _ width: CGFloat? = nil, _ closure: AlertClosure? = nil) {
		FOREGROUND { [self] in
			let a = alert(message, information, iOKTitle, iCancelTitle, iImage, width)

			closure?(a, .sShow)
		}
	}

	func alert(_ message: String = "Warning", _ information: String? = nil, _ iOKTitle: String = "OK", _ iCancelTitle: String? = nil, _ iImage: ZImage? = nil, _ width: CGFloat? = nil) -> ZAlert {
		let        a = inform(message, information)
		a.alertStyle = .critical

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
			let       frame = CGRect(x: .zero, y: .zero, width: w, height: .zero)
			a.accessoryView = ZView(frame: frame)
			a.layout()
		}

		return a
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
		gTextEditor.prepareUndoForTextChange(undoManager) { [self] in
            textDidChange(iNote)
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
			let number = notification.userInfo?["NSTextMovement"] as? NSNumber {
            let  value = number.intValue
			let  flags = gModifierFlags
            var    key : String?

			gTextEditor.stopCurrentEdit(forceCapture: true, andRedraw: false)

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
		if  let  type = ZSpecialCharactersMenuType(rawValue: iItem.keyEquivalent),
			let range = selectedRanges[0] as? NSRange,
			type     != .eCancel {
			let  text = type.text

			insertText(text, replacementRange: range)
		}
	}

    override func doCommand(by selector: Selector) {
        switch selector {
        case #selector(insertNewline):       stopCurrentEdit()
        case #selector(insertTab):           if currentEdit?.adequatelyPaused ?? true { gSelecting.rootMostMoveable?.addNextAndRelayout() } // stupid OSX issues tab twice (to create the new idea, then once MORE
		case #selector(cancelOperation(_:)): if gSearchStateIsEntry || gSearchStateIsList { gExitSearchMode() }
        default:                             super.doCommand(by: selector)
        }
    }
	
	@discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags) -> Bool {   // false means key not handled
		if  var        key = iKey, !gRefusesFirstResponder {
			let        ANY = flags.isAny
			let     OPTION = flags.hasOption
			let    CONTROL = flags.hasControl
			let editedZone = currentTextWidget?.widgetZone
			let      arrow = key.arrow

			if  key       != key.lowercased() {
				key        = key.lowercased()
			}

			gHideExplanation()

			if  let      a = arrow {
				gTextEditor.handleArrow(a, flags: flags)
			} else if ANY {
				switch key {
					case "a":       currentTextWidget?.selectAllText()
					case "d":       editedZone?.tearApartCombine(flags)
					case "e":       gToggleShowExplanations()
					case "f":       gSearching.showSearch(OPTION)
					case "i":       showSpecialCharactersPopup()
					case kQuestion: gHelpController?.show(flags: flags)
					case kTab:      gSelecting.addSibling(OPTION)
					case kSpace:    editedZone?.addIdea()
					case kReturn:   stopCurrentEdit()
					case kHyphen:   return editedZone?.convertToFromLine() ?? false // false means key not handled
					case kDelete,
  					kBackspace:     if CONTROL { gFocusing.grabAndFocusOn(gTrash) { gRelayoutMaps() } }
					default:        return false
				}
	  		} else if kSurroundKeys.contains(key) {
				return              editedZone?.surround(by: key) ?? false
			} else {
	  			switch key {
	  				case kEscape:   cancel()
					case kReturn:   stopCurrentEdit()
					case kTab:      gSelecting.addSibling()
					case kHyphen:   return editedZone?.convertToFromLine() ?? false
					default:        return false // false means key not handled
				}
	  		}
		}

		return true
	}

    func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
		if gIsHelpFrontmost { return }

        switch arrow {
        case .up,
             .down: moveUp(arrow == .up, stopEdit: !flags.hasOption)
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

	static func mutateTextPopup(target: AnyObject, action: Selector) -> ZMenu {
		let menu = ZMenu(title: "change text")

		for type in ZMutateTextMenuType.allTypes {
			menu.addItem(mutateTextItem(type: type, target: target, action: action))
		}

		return menu
	}

	static func mutateTextItem(type: ZMutateTextMenuType, target: AnyObject, action: Selector) -> ZMenuItem {
		let  	  item = ZMenuItem(title: type.title, action: action, keyEquivalent: type.rawValue)
		item.isEnabled = true
		item.target    = target
		item.keyEquivalentModifierMask = ZEventFlags(rawValue: 0)

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

	enum ZRefetchMenuType: String {
		case eList    = "l"
		case eIdeas   = "g"
		case eAdopt   = "a"
		case eTraits  = "t"
		case eProgeny = "p"

		static var activeTypes: [ZRefetchMenuType] { return [.eIdeas, .eTraits, .eProgeny, .eList, .eAdopt] }

		var title: String {
			switch self {
			case .eList:    return "list"
			case .eAdopt:   return "adopt"
			case .eIdeas:   return "all ideas"
			case .eTraits:  return "all traits"
			case .eProgeny: return "all progeny"
			}
		}
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
		let COMMAND = flags.hasCommand
		let  OPTION = flags.hasOption
		let   SHIFT = flags.hasShift
		
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

	func startAnimating() { isHidden = false; startAnimation(self) }
	func  stopAnimating() { isHidden = true;   stopAnimation(self) }

}

public extension ZImage {

	var  png: Data? { return tiffRepresentation?.bitmap?.png }
	var jpeg: Data? { return tiffRepresentation?.bitmap?.jpeg }

	func imageResizedTo(_ newSize: CGSize) -> ZImage? {
		if  let bitmapRep = NSBitmapImageRep(
			bitmapDataPlanes      : nil,
			pixelsWide            : Int(newSize.width  * 2.0),
			pixelsHigh            : Int(newSize.height * 2.0),
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
        var imageBounds = NSZeroRect ; imageBounds.size = size
        let pathBounds = NSBezierPath(rect: imageBounds)
        var transform = NSAffineTransform()
		let rotatedBounds:CGRect = NSMakeRect(NSZeroPoint.x, NSZeroPoint.y , size.width, size.height )
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
		draw(in: imageBounds, from: .zero, operation: .copy, fraction: 1.0)
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

extension Zone {

    func hasZoneAbove(_ iAbove: Bool) -> Bool {
        if  let index = siblingIndex {
            return index != (iAbove ? 0 : (parentZone!.count - 1))
        }

        return false
    }

}

extension ZoneLine {

	func lineRect(for kind: ZLineCurveKind?) -> CGRect {
		switch mode {
		case .linearMode:   return   linearLineRect(for: kind)
		case .circularMode: return circularLineRect()
		}
	}

	func circularLineRect() -> CGRect {
		if  let origin = revealDot?.absoluteCenter,
			let center =   dragDot?.absoluteCenter {
			let   size = CGSize(center - origin).absSize
			return CGRect(origin: origin, size: size)
		}

		return .zero
	}

    func linearLineRect(for kind: ZLineCurveKind?) -> CGRect {
		var                 rect = CGRect.zero
		if  kind                != nil,
			let                c = controller ?? gHelpController, // for help dots, widget and controller are nil; so use help controller
        	let        fromFrame = revealDot?.absoluteFrame,
			let          toFrame = dragDot?.absoluteFrame {
			let        thickness = c.coreThickness
			let            delta = CGFloat(4)
			let       smallDelta = CGFloat(1)
			rect       .origin.x = fromFrame    .midX
			rect     .size.width = abs(  toFrame.minX - rect.minX)

            switch kind! {
            case .above:
				rect.origin   .y =     fromFrame.midY              - delta
				rect.size.height = abs(  toFrame.midY - rect.minY)
            case .below:
				rect.origin   .y =       toFrame.midY              - smallDelta
				rect.size.height = abs(fromFrame.midY - rect.minY) - delta
            case .straight:
				rect.origin   .y =     fromFrame.midY              - smallDelta
                rect.size.height = thickness
            }
        }
        
        return rect
    }

    func curvedLinePath(in iRect: CGRect, kind: ZLineCurveKind) -> ZBezierPath {
		guard let        c = controller else { return ZBezierPath() }
        let        isAbove = kind == .above
		let     aboveDelta = c.dotHalfHeight / 7.0
		let     belowDelta =     c.dotHeight * 0.85
        var           rect = iRect

        if  isAbove {
            rect.origin.y -= rect.height + aboveDelta    // do this first. height is altered below
		} else if kind == .below {
			rect.origin.y += c.dotHalfHeight / 4.0
		}

		rect.size   .width = rect.width  * 2.0 + c.dotHalfWidth
		rect.size  .height = rect.height * 2.0 + (isAbove ? aboveDelta : belowDelta)

		ZBezierPath.setClip(to: iRect)

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
