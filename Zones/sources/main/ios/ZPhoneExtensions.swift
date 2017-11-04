//
//  ZPhoneExtensions.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import UserNotifications
import Foundation
import CloudKit
import UIKit


enum ZArrowKey: CChar {
    case up    = 85 // U
    case down  = 68 // D
    case left  = 76 // L
    case right = 82 // R
}


public typealias ZFont                      = UIFont
public typealias ZView                      = UIView
public typealias ZImage                     = UIImage
public typealias ZColor                     = UIColor
public typealias ZEvent                     = UIKeyCommand
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
public typealias ZScrollDelegate            = UIScrollViewDelegate
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
public typealias ZGestureRecognizerState    = UIGestureRecognizerState
public typealias ZGestureRecognizerDelegate = UIGestureRecognizerDelegate


let      gHighlightHeightOffset = CGFloat(3.0)
let             gVerticalWeight = -1.0
let                gApplication = UIApplication.shared
var windowKeys: [UIKeyCommand]? = nil


func NSStringFromSize(_ size: CGSize) -> String {
    return NSStringFromCGSize(size)
}


func NSStringFromPoint(_ point: CGPoint) -> String {
    return NSStringFromCGPoint(point)
}


extension NSObject {
    func assignAsFirstResponder(_ responder: UIResponder?) {
        responder?.becomeFirstResponder()
    }
}


extension UIKeyCommand {
    var key: String {

        if input.hasPrefix("UIKeyInput") {
            return input.character(at: 10)
        }

        return input.character(at: 0)
    }
}


extension String {
    var cgPoint: CGPoint { return CGPointFromString(self) }
    var cgSize:   CGSize { return  CGSizeFromString(self) }
    var arrow: ZArrowKey? {
        let value = utf8CString[0]

        for arrowKey in [ZArrowKey.up.rawValue, ZArrowKey.down.rawValue, ZArrowKey.left.rawValue, ZArrowKey.right.rawValue] {
            if arrowKey == value {
                return ZArrowKey(rawValue: value)
            }
        }

        return nil
    }

}


extension UIBezierPath {
    func setClip()         { addClip() }
    func line(to: CGPoint) { addLine(to: to) }
}


extension UIColor {
    var string: String {
        var   red: CGFloat = 0.0
        var  blue: CGFloat = 0.0
        var green: CGFloat = 0.0
        var alpha: CGFloat = 0.0

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return "red:\(red),blue:\(blue),green:\(green)"
    }

    func darker(by: CGFloat) -> UIColor {
        var        hue: CGFloat = 0.0
        var      alpha: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0

        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return UIColor(hue: hue, saturation: saturation * 1.1, brightness: brightness / by, alpha: alpha)
    }

    func lighter(by: CGFloat) -> UIColor {
        var        hue: CGFloat = 0.0
        var      alpha: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0

        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return UIColor(hue: hue, saturation: saturation * 0.9, brightness: brightness * by, alpha: alpha)
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

    func    moveUpEvent(_ iGesture: ZGestureRecognizer?) { gEditingManager  .moveUp() }
    func  moveDownEvent(_ iGesture: ZGestureRecognizer?) { gEditingManager  .moveUp(false) }
    func  moveLeftEvent(_ iGesture: ZGestureRecognizer?) { gEditingManager .moveOut() }
    func moveRightEvent(_ iGesture: ZGestureRecognizer?) { gEditingManager.moveInto() }

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
                e.clickGesture     = createPointGestureRecognizer(e, action: #selector(ZEditorController          .clickEvent), clicksRequired: 1)
                e.moveUpGesture    = createSwipeGestureRecognizer(e, action: #selector(ZEditorController         .moveUpEvent), direction: .up,    touchesRequired: 2)
                e.moveDownGesture  = createSwipeGestureRecognizer(e, action: #selector(ZEditorController       .moveDownEvent), direction: .down,  touchesRequired: 2)
                e.moveLeftGesture  = createSwipeGestureRecognizer(e, action: #selector(ZEditorController       .moveLeftEvent), direction: .left,  touchesRequired: 2)
                e.moveRightGesture = createSwipeGestureRecognizer(e, action: #selector(ZEditorController      .moveRightEvent), direction: .right, touchesRequired: 2)
                e.movementGesture  = createDragGestureRecognizer (e, action: #selector(ZEditorController.movementGestureEvent))
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


    override open func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if  event?.subtype == UIEventSubtype.motionShake && !gKeyboardIsVisible {
            gEditingManager.recenter()
        }
    }

}


extension UIWindow {


    var contentView: UIView? { return self }
    override open var canBecomeFirstResponder: Bool { return true }


    override open var keyCommands: [UIKeyCommand]? {
        if gSelectionManager.currentlyEditingZone != nil {
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
            let pairs:             [String: String] = ["up arrow"        : UIKeyInputUpArrow,
                                                       "down arrow"      : UIKeyInputDownArrow,
                                                       "left arrow"      : UIKeyInputLeftArrow,
                                                       "right arrow"     : UIKeyInputRightArrow]

            for (prefix, flags) in mods {
                for (title, input) in pairs {
                    windowKeys?.append(UIKeyCommand(input: input, modifierFlags: flags,  action: handler, discoverabilityTitle: prefix + title))
                }

                for character in "abcdefghijklmnopqrstuvwxyz/ '\t\r\u{8}".characters {
                    let input = String(character)

                    windowKeys?.append(UIKeyCommand(input: input, modifierFlags: flags,  action: handler, discoverabilityTitle: prefix + input))
                }
            }
        }

        return windowKeys
    }


    func keyHandler(command: UIKeyCommand) {
        var event = command

        if  let title = command.discoverabilityTitle, title.contains(" arrow") { // flags need a .numericPad option added
            let flags = UIKeyModifierFlags(rawValue: command.modifierFlags.rawValue + UIKeyModifierFlags.numericPad.rawValue)
            event     = UIKeyCommand(input: command.input, modifierFlags: flags, action: #selector(UIWindow.keyHandler), discoverabilityTitle: command.discoverabilityTitle!)
        }

        gEditingManager.handleEvent(event, isWindow: true)
    }

}


extension UITextField {
    var isBordered : Bool { get { return borderStyle != .none } set { borderStyle = (newValue ? .line : .none) } }
    override open var canBecomeFirstResponder: Bool { return true } // gOperationsManager.isAvailable }    // fix a bug where root zone is editing on launch
    func enableUndo() {}
    func abortEditing() { resignFirstResponder() }
    func selectAllText() { selectAll(self) }

    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        resignFirstResponder()

        return true
    }
}


extension ZoneTextWidget {
    @objc(textField:shouldChangeCharactersInRange:replacementString:) func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        widget.textWidget.layoutTextField()
        gEditorView?.setAllSubviewsNeedDisplay()

        return true
    }
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


extension ZoneWidget {


    func dragHitFrame(in iView: ZView?, _ iHere: Zone) -> CGRect {
        var hitRect = CGRect()

        if  let   view = iView,
            let    dot = dragDot.innerDot {
            let isHere = widgetZone == iHere
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


    func lineRect(to rightFrame: CGRect, kind: ZLineKind?) -> CGRect {
        var frame = CGRect ()

        if  let       leftDot = toggleDot.innerDot, kind != nil {
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
                frame.size.height = fabs( rightMidY + thinThickness - frame.minY)
            case .above:
                frame.origin   .y = rightFrame.maxY - halfDotHeight
                frame.size.height = fabs(  leftMidY - thinThickness - frame.minY)
            case .straight:
                frame.origin   .y =       rightMidY - thinThickness / 8.0
                frame.origin   .x = leftFrame .maxX
                frame.size.height =                   thinThickness / 4.0
            }

            frame.size     .width = fabs(rightFrame.midX - frame.minX)
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
