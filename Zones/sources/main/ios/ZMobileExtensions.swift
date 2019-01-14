//
//  ZMobileExtensions.swift
//  Thoughtful
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


public typealias ZFont                      = UIFont
public typealias ZView                      = UIView
public typealias ZAlert                     = UIAlertController
public typealias ZImage                     = UIImage
public typealias ZColor                     = UIColor
public typealias ZEvent                     = UIEvent
public typealias ZButton                    = UIButton
public typealias ZWindow                    = UIWindow
public typealias ZSlider                    = UISlider
public typealias ZControl                   = UIControl
public typealias ZMenuItem                  = UIMenuItem
public typealias ZTextView                  = UITextView
public typealias ZTextField                 = UITextField
public typealias ZTableView                 = UITableView
public typealias ZScrollView                = UIScrollView
public typealias ZController                = UIViewController
public typealias ZEventFlags                = UIKeyModifierFlags
public typealias ZBezierPath                = UIBezierPath
public typealias ZSearchField               = UISearchBar
public typealias ZApplication               = UIApplication
public typealias ZWindowDelegate            = ZNullProtocol
public typealias ZScrollDelegate            = UIScrollViewDelegate
public typealias ZWindowController          = UIWindowController
public typealias ZSegmentedControl          = UISegmentedControl
public typealias ZGestureRecognizer         = UIGestureRecognizer
public typealias ZProgressIndicator         = UIActivityIndicatorView
public typealias ZTextFieldDelegate         = UITextFieldDelegate
public typealias ZTableViewDelegate         = UITableViewDelegate
public typealias ZSearchFieldDelegate       = UISearchBarDelegate
public typealias ZTableViewDataSource       = UITableViewDataSource
public typealias ZApplicationDelegate       = UIApplicationDelegate
public typealias ZPanGestureRecognizer      = UIPanGestureRecognizer
public typealias ZClickGestureRecognizer    = UITapGestureRecognizer
public typealias ZSwipeGestureRecognizer    = UISwipeGestureRecognizer
public typealias ZGestureRecognizerState    = UIGestureRecognizer.State
public typealias ZGestureRecognizerDelegate = UIGestureRecognizerDelegate


public protocol ZNullProtocol {}


let      gHighlightHeightOffset = CGFloat(3.0)
let             gVerticalWeight = -1.0
let                gApplication = UIApplication.shared
var windowKeys: [UIKeyCommand]?


func NSStringFromSize(_ size: CGSize) -> String {
    return NSCoder.string(for: size)
}


func NSStringFromPoint(_ point: CGPoint) -> String {
    return NSCoder.string(for: point)
}


extension NSObject {

    func assignAsFirstResponder(_ responder: UIResponder?) {
        responder?.becomeFirstResponder()
    }

}


extension UIKeyCommand {

    var key: String? {
        var working = input

        if  working.hasPrefix("UIKeyInput") {
            working = String(input.dropFirst(10))

            if working.count > 1 {
                return nil
            }
        }

        return working.character(at: 0)
    }


    var arrow: ZArrowKey? {
        var working = input

        if  working.hasPrefix("UIKeyInput") {
            working = String(input.dropFirst(10))

            if working.count > 1 {
                let value = working.character(at: 0)

                return value.arrow
            }
        }

        return nil
    }

}


extension String {

    var cgPoint: CGPoint { return NSCoder.cgPoint(for: self) }
    var cgSize:   CGSize { return  NSCoder.cgSize(for: self) }
    var arrow: ZArrowKey? {
        let value = utf8CString[0]

        for arrowKey in [ZArrowKey.up.rawValue, ZArrowKey.down.rawValue, ZArrowKey.left.rawValue, ZArrowKey.right.rawValue] {
            if arrowKey == value {
                return ZArrowKey(rawValue: value)
            }
        }

        return nil
    }

    func heightForFont(_ font: ZFont, options: String.DrawingOptions = []) -> CGFloat { return sizeWithFont(font, options: options).height }
    func sizeWithFont (_ font: ZFont, options: NSString.DrawingOptions = .usesFontLeading) -> CGSize { return rectWithFont(font, options: options).size }
    
    
    func rectWithFont(_ font: ZFont, options: NSString.DrawingOptions = .usesFontLeading) -> CGRect {
        let attributes = convertToOptionalNSAttributedStringKeyDictionary([kCTFontAttributeName as String : font])
        
        return boundingRect(with: CGSize.big, options: options, attributes: attributes, context: nil)
    }

    func openAsURL() {
        if let url = URL(string: self) {
            UIApplication.shared.open(url)
        }
    }

}


extension UIBezierPath {

    func setClip()         { addClip() }
    func line(to: CGPoint) { addLine(to: to) }

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
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        self.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
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

    func darkish(by: CGFloat) -> ZColor {
        let components = hsba

        return ZColor(hue: components.hue, saturation: components.saturation, brightness: components.brightness / by, alpha: components.alpha)
    }

    func lighter(by: CGFloat) -> ZColor {
        let components = hsba

        return ZColor(hue: components.hue, saturation: components.saturation * 0.9, brightness: components.brightness * by, alpha: components.alpha)
    }

}


extension UIKeyModifierFlags {

    var isNumericPad: Bool { return contains(.numericPad) }
    var isControl:    Bool { return contains(.control) }
    var isCommand:    Bool { return contains(.command) }
    var isOption:     Bool { return contains(.alternate) }
    var isShift:      Bool { return contains(.shift) }

}


extension ZEditorController {

    func    moveUpEvent(_ iGesture: ZGestureRecognizer?) { gGraphEditor  .moveUp() }
    func  moveDownEvent(_ iGesture: ZGestureRecognizer?) { gGraphEditor  .moveUp(false) }
    func  moveLeftEvent(_ iGesture: ZGestureRecognizer?) { gGraphEditor .moveOut() }
    func moveRightEvent(_ iGesture: ZGestureRecognizer?) { gGraphEditor.moveInto() }

}


extension   UISwipeGestureRecognizerDirection {

    var all:UISwipeGestureRecognizerDirection {     return
            UISwipeGestureRecognizerDirection (     rawValue :
            UISwipeGestureRecognizerDirection.right.rawValue +
            UISwipeGestureRecognizerDirection .left.rawValue +
            UISwipeGestureRecognizerDirection .down.rawValue +
            UISwipeGestureRecognizerDirection   .up.rawValue
        )
    }

}


extension UIView {

    var      zlayer:               CALayer { return layer }
    var recognizers: [ZGestureRecognizer]? { return gestureRecognizers }


    var gestureHandler: ZEditorController? {
        get { return nil }
        set {
            clearGestures()

            if let e = newValue {
                e.clickGesture     = createPointGestureRecognizer(e, action: #selector(ZEditorController       .clickEvent), clicksRequired: 1)
                e.moveUpGesture    = createSwipeGestureRecognizer(e, action: #selector(ZEditorController      .moveUpEvent), direction: .up,    touchesRequired: 2)
                e.moveDownGesture  = createSwipeGestureRecognizer(e, action: #selector(ZEditorController    .moveDownEvent), direction: .down,  touchesRequired: 2)
                e.moveLeftGesture  = createSwipeGestureRecognizer(e, action: #selector(ZEditorController    .moveLeftEvent), direction: .left,  touchesRequired: 2)
                e.moveRightGesture = createSwipeGestureRecognizer(e, action: #selector(ZEditorController   .moveRightEvent), direction: .right, touchesRequired: 2)
                e.movementGesture  = createDragGestureRecognizer (e, action: #selector(ZEditorController.dragGestureEvent))
                gDraggedZone       = nil
            }
        }
    }


    func display() {}


    @discardableResult func createSwipeGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?, direction: UISwipeGestureRecognizerDirection, touchesRequired: Int) -> ZKeySwipeGestureRecognizer {
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
            gGraphEditor.recenter()
        }
    }

}


extension UIWindow {

    var contentView: UIView? { return self }
    override open var canBecomeFirstResponder: Bool { return true }


    override open var keyCommands: [UIKeyCommand]? {
        if gTextEditor.isEditing != nil {
            return nil
        }

        if  windowKeys                             == nil {
            windowKeys                              = [UIKeyCommand] ()
            let                             handler = #selector(UIWindow.keyHandler)
            let                              noMods = UIKeyModifierFlags(rawValue: 0)
            let                         shiftOption = UIKeyModifierFlags(rawValue: UIKeyModifierFlags.alternate.rawValue + UIKeyModifierFlags.shift.rawValue)
            let                       commandOption = UIKeyModifierFlags(rawValue: UIKeyModifierFlags.alternate.rawValue + UIKeyModifierFlags.command.rawValue)
            let                        commandShift = UIKeyModifierFlags(rawValue: UIKeyModifierFlags    .shift.rawValue + UIKeyModifierFlags.command.rawValue)
            let mods: [String : UIKeyModifierFlags] = [""                :  noMods,
                                                       "option "         : .alternate,
                                                       "option shift "   :  shiftOption,
                                                       "command shift "  :  commandShift,
                                                       "command option " :  commandOption,
                                                       "command "        : .command,
                                                       "shift "          : .shift]
            let pairs:             [String: String] = ["up arrow"        : UIKeyCommand.inputUpArrow,
                                                       "down arrow"      : UIKeyCommand.inputDownArrow,
                                                       "left arrow"      : UIKeyCommand.inputLeftArrow,
                                                       "right arrow"     : UIKeyCommand.inputRightArrow]

            for (prefix, flags) in mods {
                for (title, input) in pairs {
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


    @objc func keyHandler(command: UIKeyCommand) {
        var event = command

        if  let title = command.discoverabilityTitle, title.contains(" arrow") { // flags need a .numericPad option added
            let flags = UIKeyModifierFlags(rawValue: command.modifierFlags.rawValue + UIKeyModifierFlags.numericPad.rawValue)
            event     = UIKeyCommand(input: command.input, modifierFlags: flags, action: #selector(UIWindow.keyHandler), discoverabilityTitle: command.discoverabilityTitle!)
        }

        gGraphEditor.handleEvent(event, isWindow: true)
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


extension ZoneTextWidget {

    @objc(textField:shouldChangeCharactersInRange:replacementString:) func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        layoutTextField()
        gEditorView?.setAllSubviewsNeedDisplay()

        return true
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


extension UIApplication {

    func presentError(_ error: NSError) {}


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
           // self.dismiss(animated: false, completion: nil)
            closure?(.eStatusShown)
        }
    }

}


extension ZFiles {
    
    
    func saveAs() {}
    func exportToFile(asOutline: Bool, for iFocus: Zone) {}
    func importFromFile(asOutline: Bool, insertInto: Zone, onCompletion: Closure?) {}

}


extension ZoneWidget {


    func dragHitFrame(in iView: ZView?, _ iHere: Zone) -> CGRect {
        var hitRect = CGRect()

        if  let   view = iView,
            let    dot = dragDot.innerDot {
            let isHere = widgetZone == iHere
            let cFrame =     convert(childrenView.frame, to: view)
            let dFrame = dot.convert(        dot.bounds, to: view)
            let bottom =  (!isHere && widgetZone?.hasZonesBelow ?? false) ? cFrame.minY : 0.0
            let    top = ((!isHere && widgetZone?.hasZonesAbove ?? false) ? cFrame      : view.bounds).maxY
            let  right =                                                        view.bounds .maxX
            let   left =    isHere ? 0.0 : dFrame.minX - gGenericOffset.width
            hitRect    = CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
        }

        return hitRect
    }


    func lineRect(to rightFrame: CGRect, kind: ZLineKind?) -> CGRect {
        var frame = CGRect ()

        if  let       leftDot = revealDot.innerDot, kind != nil {
            let     leftFrame = leftDot.convert( leftDot.bounds, to: self)
            let     thickness = CGFloat(gLineThickness)
            let     dotHeight = CGFloat(gDotHeight)
            let halfDotHeight = dotHeight / 2.0
            let thinThickness = thickness / 2.0
            let     rightMidY = rightFrame.midY
            let      leftMidY = leftFrame .midY
            frame.origin   .x = leftFrame .midX

            switch kind! {
            case .below:
                frame.origin   .y = leftFrame .minY + thinThickness + halfDotHeight
                frame.size.height = abs(  rightMidY + thinThickness - frame.minY)
            case .above:
                frame.origin   .y = rightFrame.maxY - halfDotHeight
                frame.size.height = abs(   leftMidY - thinThickness - frame.minY)
            case .straight:
                frame.origin   .y =       rightMidY - thinThickness / 8.0
                frame.origin   .x = leftFrame .maxX
                frame.size.height =                   thinThickness / 4.0
            }

            frame.size     .width = abs(rightFrame.midX - frame.minX)
        }

        return frame
    }


    func curvedPath(in iRect: CGRect, kind iKind: ZLineKind) -> ZBezierPath {
        let    isBelow = iKind == .below
        let startAngle = CGFloat(Double.pi)
        let deltaAngle = CGFloat(Double.pi / 2.0)
        let multiplier = CGFloat(isBelow ? -1.0 : 1.0)
        let   endAngle = startAngle + (multiplier * deltaAngle)
        let     scaleY = iRect.height / iRect.width
        let    centerY = isBelow ? iRect.minY : iRect.maxY
        let     center = CGPoint(x: iRect.maxX, y: centerY / scaleY)
        let       path = ZBezierPath(arcCenter: center, radius: iRect.width, startAngle: startAngle, endAngle: endAngle, clockwise: !isBelow)

        path.apply(CGAffineTransform(scaleX: 1.0, y: scaleY))

        return path
    }

}


extension ZGraphEditor {
    
    
    func showHideKeyboardShortcuts(hide: Bool? = nil) {}

}
