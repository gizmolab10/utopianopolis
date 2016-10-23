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
    public typealias ZoneTextField          = NSTextField
    public typealias ZOutlineView           = NSOutlineView
    public typealias ZApplication           = NSApplication
    public typealias ZViewController        = NSViewController
    public typealias ZSegmentedControl      = NSSegmentedControl
    public typealias ZoneTextFieldDelegate  = NSTextFieldDelegate
    public typealias ZApplicationDelegate   = NSApplicationDelegate
    public typealias ZOutlineViewDataSource = NSOutlineViewDataSource    


    let zapplication = ZApplication.shared()


#elseif os(iOS)


    import UIKit
    import CoreData


    public typealias ZFont                  = UIFont
    public typealias ZView                  = UIView
    public typealias ZColor                 = UIColor
    public typealias ZButton                = UIButton
    public typealias ZOutlineView           = UITableView
    public typealias ZoneTextField          = UITextField
    public typealias ZApplication           = UIApplication
    public typealias ZViewController        = UIViewController
    public typealias ZSegmentedControl      = UISegmentedControl
    public typealias ZoneTextFieldDelegate  = UITextFieldDelegate
    public typealias ZApplicationDelegate   = UIApplicationDelegate
    public typealias ZOutlineViewDataSource = UITableViewDataSource


    let zapplication = ZApplication.shared


#endif
