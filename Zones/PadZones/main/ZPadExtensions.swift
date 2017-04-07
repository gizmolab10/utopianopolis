//
//  ZPadExtensions.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Zones. All rights reserved.
//


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
public typealias ZEventFlags                = UIKeyModifierFlags
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
public typealias ZGestureRecognizerState    = UIGestureRecognizerState
public typealias ZGestureRecognizerDelegate = UIGestureRecognizerDelegate


let    zapplication = UIApplication.shared
let gVerticalWeight = -1.0


func NSStringFromSize(_ size: CGSize) -> String {
    return NSStringFromCGSize(size)
}


extension NSObject {
    var highlightHeightOffset: CGFloat { return 3.0 }
    var  lineThicknessDivisor: CGFloat { return 1.0 }
    func assignAsFirstResponder(_ responder: UIResponder?) { responder?.becomeFirstResponder() }
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
    var cgSize: CGSize { return CGSizeFromString(self) }
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
    func darker(by: CGFloat) -> UIColor {
        var        hue: CGFloat = 0.0
        var      alpha: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0

        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
}


extension UIKeyModifierFlags {
    var isNumericPad: Bool { get { return contains(.numericPad) } }
    var isCommand:    Bool { get { return contains(.command) } }
    var isOption:     Bool { get { return contains(.alternate) } }
    var isShift:      Bool { get { return contains(.shift) } }
}


extension UIView {
    var      zlayer:               CALayer { get { return layer } }
    var recognizers: [ZGestureRecognizer]? { get { return gestureRecognizers } }


    func clearBackground() { zlayer.isOpaque = false }
    func display() {}


    @discardableResult func createPointGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?, clicksRequired: Int) -> ZGestureRecognizer {
        let              gesture = UITapGestureRecognizer(target: target, action: action)
        isUserInteractionEnabled = true

        if recognizers != nil {
            clearGestures()
        }

        addGestureRecognizer(gesture)

        return gesture
    }


    @discardableResult func createDragGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?) -> ZGestureRecognizer {
        let      gesture = UIPanGestureRecognizer(target: target, action: action)
        gesture.delegate = target

        addGestureRecognizer(gesture)
        
        return gesture
    }
}


var windowKeys: [UIKeyCommand]? = nil


extension UIWindow {
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
    override open var canBecomeFirstResponder: Bool { return gOperationsManager.isReady }    // fix a bug where root zone is editing on launch
    func abortEditing() { resignFirstResponder() }
    func selectAllText() { selectAll(self) }
    func removeMonitorAsync() {}
    func addMonitor() {}

    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        resignFirstResponder()

        return true
    }
}


extension ZoneTextWidget {
    @objc(textField:shouldChangeCharactersInRange:replacementString:) func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        widget.layoutTextField()
        gEditorView?.applyToAllSubviews { iView in
            iView.setNeedsDisplay()
        }

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
    var selectedSegment: Int { get { return selectedSegmentIndex } }
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


extension UIApplication {

    func presentError(_ error: NSError) {}


    func clearBadge() {
        applicationIconBadgeNumber += 1
        applicationIconBadgeNumber  = 0

        cancelAllLocalNotifications()
    }
}


extension Zone {
    func hasZoneAbove(_ iAbove: Bool) -> Bool {
        if  let    index  = siblingIndex {
            return index != (!iAbove ? 0 : (parentZone!.count - 1))
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
        let startAngle = CGFloat(M_PI)
        let deltaAngle = CGFloat(M_PI_2)
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
