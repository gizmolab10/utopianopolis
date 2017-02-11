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
public typealias ZGestureRecognizerDelegate = UIGestureRecognizerDelegate


let zapplication = UIApplication.shared


func NSStringFromSize(_ size: CGSize) -> String {
    return NSStringFromCGSize(size)
}


extension NSObject {
    func assignAsFirstResponder(_ responder: UIResponder?) {
        responder?.becomeFirstResponder()
    }
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


    func clear() { zlayer.isOpaque = false }
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


var _keyCommands: [UIKeyCommand]? = nil


extension UIApplication {

    func presentError(_ error: NSError) {}


    func clearBadge() {
        applicationIconBadgeNumber += 1
        applicationIconBadgeNumber  = 0

        cancelAllLocalNotifications()
    }


    override open var keyCommands: [UIKeyCommand]? {
        get {
            if gSelectionManager.currentlyEditingZone != nil {
                return nil
            }

            if  _keyCommands == nil {
                _keyCommands = [UIKeyCommand] ()
                let   action = #selector(UIApplication.action)

                for character in "abcdefghijklmnopqrstuvwxyz '\t\r/".characters {
                    _keyCommands?.append(UIKeyCommand(input: String(character),    modifierFlags: .init(rawValue: 0), action: action))
                    _keyCommands?.append(UIKeyCommand(input: String(character),    modifierFlags: .alternate,         action: action))
                    _keyCommands?.append(UIKeyCommand(input: String(character),    modifierFlags: .command,           action: action))
                    _keyCommands?.append(UIKeyCommand(input: String(character),    modifierFlags: .shift,             action: action))
                }

                _keyCommands?.append    (UIKeyCommand(input: UIKeyInputUpArrow,    modifierFlags: .numericPad,        action: action))
                _keyCommands?.append    (UIKeyCommand(input: UIKeyInputDownArrow,  modifierFlags: .numericPad,        action: action))
                _keyCommands?.append    (UIKeyCommand(input: UIKeyInputLeftArrow,  modifierFlags: .numericPad,        action: action))
                _keyCommands?.append    (UIKeyCommand(input: UIKeyInputRightArrow, modifierFlags: .numericPad,        action: action))
            }

            return _keyCommands
        }
    }


    func action(command: UIKeyCommand) {
        gEditingManager.handleEvent(command, isWindow: true)
    }

}
