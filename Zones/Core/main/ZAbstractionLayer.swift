//
//  ZAbstractionLayer.swift
//  Zones
//
//  Created by Jonathan Sand on 7/5/16.
//  Copyright © 2016 Zones. All rights reserved.
//


#if os(OSX)


    import Cocoa


    public typealias ZFont                  = NSFont
    public typealias ZView                  = NSView
    public typealias ZColor                 = NSColor
    public typealias ZButton                = NSButton
    public typealias ZoneWidget             = NSTextField
    public typealias ZOutlineView           = NSOutlineView
    public typealias ZApplication           = NSApplication
    public typealias ZViewController        = NSViewController
    public typealias ZoneWidgetDelegate     = NSTextFieldDelegate
    public typealias ZApplicationDelegate   = NSApplicationDelegate
    public typealias ZOutlineViewDataSource = NSOutlineViewDataSource


    extension ZoneWidget {
        var text: String? {
            get { return self.stringValue }
            set { self.stringValue = newValue! }
        }
    }
    


#elseif os(iOS)


    import UIKit
    import CoreData


    public typealias ZFont                  = UIFont
    public typealias ZView                  = UIView
    public typealias ZColor                 = UIColor
    public typealias ZButton                = UIButton
    public typealias ZoneWidget             = UITextField
    public typealias ZOutlineView           = UITableView
    public typealias ZApplication           = UIApplication
    public typealias ZViewController        = UIViewController
    public typealias ZoneWidgetDelegate     = UITextFieldDelegate
    public typealias ZApplicationDelegate   = UIApplicationDelegate
    public typealias ZOutlineViewDataSource = UITableViewDataSource


    extension ZApplication {
        func presentError(_ error: NSError) -> Void {

        }
    }


#endif
