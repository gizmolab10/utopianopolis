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
public typealias ZEventFlags                = UIEventType
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


extension UIEventType {
    var isCommand: Bool { get { return false } }
    var isOption:  Bool { get { return false } }
    var isShift:   Bool { get { return false } }
}


extension UIApplication {

    func presentError(_ error: NSError) {}


    func clearBadge() {
        applicationIconBadgeNumber += 1
        applicationIconBadgeNumber  = 0

        cancelAllLocalNotifications()
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
