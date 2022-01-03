//
//  ZMobileExtensions.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import UserNotifications
import Foundation
import CloudKit
import UIKit

enum ZArrowKey: Int8 {
    case up    = 85 // U
    case down  = 68 // D
    case left  = 76 // L
    case right = 82 // R
}

public typealias ZFont                       = UIFont
public typealias ZView                       = UIView
public typealias ZAlert                      = UIAlertController
public typealias ZImage                      = UIImage
public typealias ZColor                      = UIColor
public typealias ZEvent                      = UIKeyCommand
public typealias ZButton                     = UIButton
public typealias ZWindow                     = UIWindow
public typealias ZSlider                     = UISlider
public typealias ZControl                    = UIControl
public typealias ZMenuItem                   = UIMenuItem
public typealias ZTextView                   = UITextView
public typealias ZTextField                  = UITextField
public typealias ZStackView                  = UIStackView
public typealias ZTableView                  = UITableView
public typealias ZScrollView                 = UIScrollView
public typealias ZController                 = UIViewController
public typealias ZEventFlags                 = UIKeyModifierFlags
public typealias ZBezierPath                 = UIBezierPath
public typealias ZSearchField                = UISearchBar
public typealias ZApplication                = UIApplication
public typealias ZTableColumn                = ZNullProtocol
public typealias ZWindowDelegate             = ZNullProtocol
public typealias ZScrollDelegate             = UIScrollViewDelegate
public typealias ZWindowController           = ZNullProtocol
public typealias ZSegmentedControl           = UISegmentedControl
public typealias ZGestureRecognizer          = UIGestureRecognizer
public typealias ZProgressIndicator          = UIActivityIndicatorView
public typealias ZTextFieldDelegate          = UITextFieldDelegate
public typealias ZTableViewDelegate          = UITableViewDelegate
public typealias ZSearchFieldDelegate        = UISearchBarDelegate
public typealias ZTableViewDataSource        = UITableViewDataSource
public typealias ZApplicationDelegate        = UIApplicationDelegate
public typealias ZPanGestureRecognizer       = UIPanGestureRecognizer
public typealias ZClickGestureRecognizer     = UITapGestureRecognizer
public typealias ZSwipeGestureRecognizer     = UISwipeGestureRecognizer
public typealias ZGestureRecognizerState     = UIGestureRecognizer.State
public typealias ZGestureRecognizerDelegate  = UIGestureRecognizerDelegate
public typealias ZEdgeSwipeGestureRecognizer = UIScreenEdgePanGestureRecognizer

public protocol ZNullProtocol {}

let             kVerticalWeight = CGFloat(-1)
var                  windowKeys : [UIKeyCommand]?
var                 gIsPrinting : Bool                                                { return false }
func           NSStringFromSize                    (_ size:        CGSize) -> String  { return NSCoder.string(for: size) }
func           NSStringFromPoint                   (_ point:      CGPoint) -> String  { return NSCoder.string(for: point) }
func           NSStringFromRect                    (_ rect:        CGRect) -> String? { return NSCoder.string(for: rect) }
func convertFromOptionalUserInterfaceItemIdentifier(_ identifier: String?) -> String? { return identifier } // Helper function inserted by Swift 4.2 migrator.

extension NSObject {

    func assignAsFirstResponder(_ responder: UIResponder?) {
        responder?.becomeFirstResponder()
    }

	func showTopLevelFunctions() {
		gActionsController.showTop()
	}

}

extension UIKeyCommand {

    var arrow: ZArrowKey? {
        if  let arrowKey = key {
            return arrowKey.arrow
        }
        
        return nil
    }

    var key: String? {
        if  var working = input {
            if  working.hasPrefix("UIKeyInput") {
                working = String(working.dropFirst(10))
            }

            return working.character(at: 0)
        }
        
        return nil
    }
    
}

extension String {

    var cgPoint: CGPoint { return NSCoder.cgPoint(for: self) }
    var cgRect:   CGRect { return NSCoder.cgRect (for: self) }
    var cgSize:   CGSize { return NSCoder.cgSize (for: self) }
    var arrow: ZArrowKey? {
        let value = utf8CString[0]

        for arrowKey in [ZArrowKey.up.rawValue, ZArrowKey.down.rawValue, ZArrowKey.left.rawValue, ZArrowKey.right.rawValue] {
            if arrowKey == value {
                return ZArrowKey(rawValue: value)
            }
        }

        return nil
    }

    func heightForFont(_ font: ZFont, options: NSStringDrawingOptions = .usesDeviceMetrics) -> CGFloat { return sizeWithFont(font, options: options).height }
    func sizeWithFont (_ font: ZFont, options: NSStringDrawingOptions = .usesFontLeading) -> CGSize { return rectWithFont(font, options: options).size }
    
    
    func rectWithFont (_ font: ZFont, options: NSStringDrawingOptions = .usesFontLeading) -> CGRect {
        return self.boundingRect(with: CGSize.big, options: options, attributes: [.font : font], context: nil)
    }

    func openAsURL() {
        if let url = URL(string: self) {
            gApplication.open(url)
        }
    }

}

extension UIBezierPath {

    func setClip()                   { addClip() }
    func line(to: CGPoint)           { addLine(to: to) }
    func appendOval(in rect: CGRect) { append(UIBezierPath(ovalIn: rect)) }

}

extension ZColor {

    var string: String {
        let components = rgba

        return "red:\(components.red),blue:\(components.blue),green:\(components.green)"
    }
    
    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return (r, g, b, a)
    }
    
    var hsba: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
		var h: CGFloat = 0.0
		var s: CGFloat = 0.0
		var b: CGFloat = 0.0
		var a: CGFloat = 0.0
		let      color = CGColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent) // avoid crash due to grey color space

		color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        return (h, s, b, a)
    }

    var inverted: ZColor {
        let components = hsba
        let b = max(0.0, min(1.0, 1.25 - components.brightness))
        let s = max(0.0, min(1.0, 1.45 - components.saturation))
        
        return ZColor(hue: components.hue, saturation: s, brightness: b, alpha: components.alpha)
    }

    func darker(by: CGFloat) -> ZColor {
        let components = hsba

        return ZColor(hue: components.hue, saturation: components.saturation * 1.1, brightness: components.brightness / by, alpha: components.alpha)
    }

    func lighter(by: CGFloat) -> ZColor {
        let components = hsba

        return ZColor(hue: components.hue, saturation: components.saturation * 0.9, brightness: components.brightness * by, alpha: components.alpha)
    }
    
    func lightish(by: CGFloat) -> ZColor {
        let components = hsba
        
        return ZColor(hue: components.hue, saturation: components.saturation, brightness: components.brightness * by, alpha: components.alpha)
    }

}

extension UIKeyModifierFlags {

    var isNumericPad: Bool { return contains(.numericPad) }
    var isControl:    Bool { return contains(.control) }
    var isCommand:    Bool { return contains(.command) }
    var isOption:     Bool { return contains(.alternate) }
    var isShift:      Bool { return contains(.shift) }

}

extension   UISwipeGestureRecognizer.Direction {

    var all:UISwipeGestureRecognizer.Direction {     return
            UISwipeGestureRecognizer.Direction (     rawValue :
            UISwipeGestureRecognizer.Direction.right.rawValue +
            UISwipeGestureRecognizer.Direction .left.rawValue +
            UISwipeGestureRecognizer.Direction .down.rawValue +
            UISwipeGestureRecognizer.Direction   .up.rawValue
        )
    }
    
}

public extension ZImage {
    
    func imageRotatedByDegrees(_ degrees: CGFloat) -> ZImage {
        return self
    }

}

extension UIView {

    var      zlayer:               CALayer { return layer }
    var recognizers: [ZGestureRecognizer]? { return gestureRecognizers }

    var gestureHandler: ZMapController? {
        get { return nil }
        set {
            clearGestures()

            if  let e = newValue {
				gDragging.draggedZones.removeAll()

                e.clickGesture = createPointGestureRecognizer(e, action: #selector(ZMapController.handleClickGesture), clicksRequired: 1)
			}
        }
    }

    func display() {}

    @discardableResult func createSwipeGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?, direction: UISwipeGestureRecognizer.Direction, touchesRequired: Int) -> ZKeySwipeGestureRecognizer {
        let                     gesture = ZKeySwipeGestureRecognizer(target: target, action: action)
        gesture               .delegate = target
        gesture              .direction = direction
        gesture.numberOfTouchesRequired = touchesRequired

        addGestureRecognizer(gesture)

        return gesture
    }

    @discardableResult func createDragGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?) -> ZKeyPanGestureRecognizer {
        let                    gesture = ZKeyPanGestureRecognizer(target: target, action: action)
        gesture              .delegate = target
        gesture.maximumNumberOfTouches = 1

        addGestureRecognizer(gesture)

        return gesture
    }

    @discardableResult func createPointGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?, clicksRequired: Int) -> ZKeyClickGestureRecognizer {
        let              gesture = ZKeyClickGestureRecognizer(target: target, action: action)
        isUserInteractionEnabled = true

        if recognizers != nil {
            clearGestures()
        }

        addGestureRecognizer(gesture)

        return gesture
    }

    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if  event?.subtype == UIEvent.EventSubtype.motionShake && !gKeyboardIsVisible {
            gMapController?.recenter()
        }
    }

	func printView() {}

}

extension ZStackableView {
    
    var identity: ZDetailsViewID { return .All }    
    
}

extension UITableView {
    
    var selectedRow: Int { return indexPathForSelectedRow?.row ?? -1 }
    var numberOfRows: Int { return numberOfRows(inSection: 0) }
    
    func selectRowIndexes(_ rows: IndexSet, byExtendingSelection: Bool) {
        let path = IndexPath(row: rows.first!, section: 0)

        selectRow(at: path, animated: false, scrollPosition: .none)
    }
    
    func scrollRowToVisible(_ row: Int) {
        let path = IndexPath(row: row, section: 0)

        scrollToRow(at: path, at: .none, animated: false)
    }
    
}

extension ZMapView {
    
    func updateMagnification(with event: ZEvent) {}
    
}

extension ZWindow {

    var contentView: UIView? { return self }
    override open var canBecomeFirstResponder: Bool { return true }

    override open var keyCommands: [UIKeyCommand]? {
        if  gIsIdeaMode {
            return nil
        }

        if  windowKeys                             == nil {
            windowKeys                              = [UIKeyCommand] ()
            let                             handler = #selector(ZWindow.handleKey)
            let                              noMods = UIKeyModifierFlags(rawValue: 0)
            let                       COMMAND_SHIFT = UIKeyModifierFlags(rawValue: UIKeyModifierFlags  .shift.rawValue + UIKeyModifierFlags  .command.rawValue)
            let                        OPTION_SHIFT = UIKeyModifierFlags(rawValue: UIKeyModifierFlags  .shift.rawValue + UIKeyModifierFlags.alternate.rawValue)
            let                             SPECIAL = UIKeyModifierFlags(rawValue: UIKeyModifierFlags.command.rawValue + UIKeyModifierFlags.alternate.rawValue)
            let mods: [String : UIKeyModifierFlags] = [""                :  noMods,
                                                       "option "         : .alternate,
                                                       "option shift "   :  OPTION_SHIFT,
                                                       "command shift "  :  COMMAND_SHIFT,
                                                       "command option " :  SPECIAL,
                                                       "command "        : .command,
                                                       "shift "          : .shift]
            let inputs: [String: String]            = ["up arrow"        : UIKeyCommand.inputUpArrow,
                                                       "down arrow"      : UIKeyCommand.inputDownArrow,
                                                       "left arrow"      : UIKeyCommand.inputLeftArrow,
                                                       "right arrow"     : UIKeyCommand.inputRightArrow]

            for (prefix, flags) in mods {
                for (title, input) in inputs {
                    windowKeys?.append(UIKeyCommand(input: input, modifierFlags: flags,  action: handler, discoverabilityTitle: prefix + title))
                }

                for character in "abcdefghijklmnopqrstuvwxyz/ '\t\r\u{8}" {
                    let input = String(character)

                    windowKeys?.append(UIKeyCommand(input: input, modifierFlags: flags,  action: handler, discoverabilityTitle: prefix + input))
                }
            }
        }

        return windowKeys
    }

    @objc func handleKey(command: UIKeyCommand) {
        var event = command

        if  let title = command.discoverabilityTitle, title.contains(" arrow"),
            let input = command.input {
            let flags = UIKeyModifierFlags(rawValue: command.modifierFlags.rawValue + UIKeyModifierFlags.numericPad.rawValue) 	// add .numericPad to flags
            event     = UIKeyCommand(input: input, modifierFlags: flags, action: #selector(UIWindow.handleKey), discoverabilityTitle: command.discoverabilityTitle!)
        }

        gMapEditor.handleEvent(event, isWindow: true)
    }

}

extension UITextField {

    var isBordered : Bool { get { return borderStyle != .none } set { borderStyle = (newValue ? .line : .none) } }
    override open var canBecomeFirstResponder: Bool { return true } // gBatch.isAvailable }    // fix a bug where root zone is editing on launch
    func enableUndo() {}
    func abortEditing() { resignFirstResponder() }
    func selectAllText() { selectAll(self) }

    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        resignFirstResponder()

        return true
    }

}

extension UISearchBar {
    
    func selectAllText() { selectAll(self) }

}

extension ZoneTextWidget {

    @objc(textField:shouldChangeCharactersInRange:replacementString:) func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        layoutTextField()
        gMapView?.setAllSubviewsNeedDisplay()

        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        gTextEditor.stopCurrentEdit()
    }
    
    func deselectAllText() {}

}

public extension UISlider {

    var doubleValue: Double {
        get { return Double(value) }
        set { value = Float(newValue) }
    }

}

extension UISegmentedControl {

	var selectedSegment: Int { return selectedSegmentIndex }

}

extension UIButton {
    @objc func nuttin() {}


    var      onHit: Selector { get { return #selector(nuttin) } set { } }
    var isCircular:     Bool { get { return true }              set { } }


    var title: String? {
        get { return title(for: .normal) }
        set { setTitle(newValue, for: .normal) }
    }

}

extension ZApplication {

    func showHideAbout() {}
    func presentError(_ error: NSError) {    }
    func terminate(_ sender: Any?) {}


    func clearBadge() {
        applicationIconBadgeNumber += 1
        applicationIconBadgeNumber  = 0

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

}

extension Zone {

    func hasZoneAbove(_ iAbove: Bool) -> Bool {
        if  let     index  = siblingIndex {
            let compareTo  = !iAbove ? 0 : (parentZone!.count - 1)
            return  index != compareTo
        }

        return false
    }

}

extension ZAlert {

    func showAlert(closure: AlertStatusClosure? = nil) {
        modalPresentationStyle = .popover

        gControllers.currentController?.present(self, animated: true) {
            self.dismiss(animated: false) {
                closure?(.sShown)
            }
        }
    }

}

extension ZAlerts {

    func openSystemPreferences() {
        if let url = URL(string: "App-Prefs:root=General&path=Network") {
            gApplication.open(url)
        }
    }
    
    func showAlert(_ iMessage: String = "Warning", _ iExplain: String? = nil, _ iOkayTitle: String = "OK", _ iCancelTitle: String? = nil, _ iImage: ZImage? = nil, _ closure: AlertStatusClosure? = nil) {
        alert(iMessage, iExplain, iOkayTitle, iCancelTitle, iImage) { iAlert, iState in
			switch iState {
				case .sShow:
					iAlert?.showAlert { iResponse in
						closure?(iResponse)
				}
				default:
					closure?(iState)
			}
        }
    }
    
    func alert(_ iMessage: String = "Warning", _ iExplain: String? = nil, _ iOKTitle: String = "OK", _ iCancelTitle: String? = nil, _ iImage: ZImage? = nil, _ closure: AlertClosure? = nil) {
        FOREGROUND(canBeDirect: true) {
            let        a = ZAlert(title: iMessage, message: iExplain, preferredStyle: .alert)
            let okAction = UIAlertAction(title: iOKTitle, style: .default) { iAction in
                closure?(a, .sYes)
            }
            
            a.addAction(okAction)
            
            closure?(a, .sShow)
        }
    }

}

extension ZFiles {

    func saveAs() {}
    func showInFinder() {}
    func importFromFile(_ type: ZExportType, insertInto: Zone, onCompletion: Closure?) {}

}

extension ZTextEditor {

    var string: String { return text }
    func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {}
	func showSpecialCharactersPopup() {}

    func fullResign()  {
        assignAsFirstResponder (nil) // ios broken?
        gMapController?.mobileKeyInput?.becomeFirstResponder()
	}
	
}

extension ZMapController {
    
    @objc func    moveUpEvent(_ iGesture: ZGestureRecognizer?) { gMapEditor.move(up: true) }
    @objc func  moveDownEvent(_ iGesture: ZGestureRecognizer?) { gMapEditor.move(up: false) }
    @objc func  moveLeftEvent(_ iGesture: ZGestureRecognizer?) { gMapEditor.move(out: true)  { gSelecting.updateAfterMove() } }
    @objc func moveRightEvent(_ iGesture: ZGestureRecognizer?) { gMapEditor.move(out: false) { gSelecting.updateAfterMove() } }
        
}

extension ZBaseEditor {
    
    func showHideKeyboardHelp(hide: Bool? = nil) {}

}

extension ZOnboarding {
    
    func getMAC() {}
        
}
