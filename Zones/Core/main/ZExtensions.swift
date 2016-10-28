//
//  ZExtensions.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


#if os(OSX)


    import Cocoa


    public typealias ZFont                  = NSFont
    public typealias ZView                  = NSView
    public typealias ZEvent                 = NSEvent
    public typealias ZImage                 = NSImage
    public typealias ZColor                 = NSColor
    public typealias ZButton                = NSButton
    public typealias ZTextField             = NSTextField
    public typealias ZEdgeInsets            = EdgeInsets
    public typealias ZApplication           = NSApplication
    public typealias ZViewController        = NSViewController
    public typealias ZSegmentedControl      = NSSegmentedControl
    public typealias ZTextFieldDelegate     = NSTextFieldDelegate
    public typealias ZApplicationDelegate   = NSApplicationDelegate
    public typealias ZOutlineViewDataSource = NSOutlineViewDataSource


    let zapplication = ZApplication.shared()


    func ZEdgeInsetsMake(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) -> EdgeInsets {
        return NSEdgeInsetsMake(top, left, bottom, right)
    }


    extension ZTextField {
        var text: String? {
            get { return stringValue }
            set { stringValue = newValue! }
        }
    }


    extension ZSegmentedControl {
        var selectedSegmentIndex: Int {
            get { return selectedSegment }
            set { selectedSegment = newValue }
        }

    }


    extension String {
        func size(attributes attrs: [String : Any]? = nil) -> NSSize {
            return size(withAttributes:attrs)
        }
    }


    extension ZApplication {
        func clearBadge() {
            dockTile.badgeLabel = ""
        }
    }


#elseif os(iOS)


    import UIKit


    public typealias ZFont                  = UIFont
    public typealias ZView                  = UIView
    public typealias ZEvent                 = UIEvent
    public typealias ZImage                 = UIImage
    public typealias ZColor                 = UIColor
    public typealias ZButton                = UIButton
    public typealias ZTextField             = UITextField
    public typealias ZEdgeInsets            = UIEdgeInsets
    public typealias ZApplication           = UIApplication
    public typealias ZViewController        = UIViewController
    public typealias ZSegmentedControl      = UISegmentedControl
    public typealias ZTextFieldDelegate     = UITextFieldDelegate
    public typealias ZApplicationDelegate   = UIApplicationDelegate
    public typealias ZOutlineViewDataSource = UITableViewDataSource


    let zapplication = ZApplication.shared


    func ZEdgeInsetsMake(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) -> EdgeInsets {
        return UIEdgeInsetsMake(top, left, bottom, right)
    }


    extension ZApplication {
        func presentError(_ error: NSError) -> Void {

        }

        
        func clearBadge() {
            applicationIconBadgeNumber += 1
            applicationIconBadgeNumber  = 0

            cancelAllLocalNotifications()
        }
    }


#endif


typealias ZStorageDict = [String : NSObject]


extension String {

    func sizeWithFont(_ font: ZFont) -> CGSize {
        return size(attributes: [NSFontAttributeName: font])
    }


    func heightForFont(_ font: ZFont) -> CGFloat {
        return sizeWithFont(font).height
    }


    func widthForFont(_ font: ZFont) -> CGFloat {
        return sizeWithFont(font).width
    }
}


//extension NSAttributedString {
//    func heightWithConstrainedWidth(width: CGFloat) -> CGFloat {
//        let constraint = CGSize(width: width, height: .greatestFiniteMagnitude)
//        let boundingBox = boundingRect(with: constraint, options: .usesLineFragmentOrigin, context: nil)
//
//        return boundingBox.height
//    }
//
//    func widthWithConstrainedHeight(height: CGFloat) -> CGFloat {
//        let constraint = CGSize(width: .greatestFiniteMagnitude, height: height)
//        let boundingBox = boundingRect(with: constraint, options: .usesLineFragmentOrigin, context: nil)
//
//        return boundingBox.width
//    }
//}



extension ZView {

    
    func addBorder(thickness: CGFloat, fractionalRadius: CGFloat, color: CGColor) {
        wantsLayer             = true
        layer!.borderColor     = color
        layer!.borderWidth     = thickness
        layer!.cornerRadius    = bounds.size.height * fractionalRadius
        // layer!.backgroundColor = CGColor.white
    }
}
