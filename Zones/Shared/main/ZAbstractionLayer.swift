//
//  ZAbstractionLayer.swift
//  Zones
//
//  Created by Jonathan Sand on 7/5/16.
//  Copyright © 2016 Zones. All rights reserved.
//


#if os(OSX)


    import Cocoa


    public typealias ZFont           = NSFont
    public typealias ZView           = NSView
    public typealias ZColor          = NSColor
    public typealias ZApplication    = NSApplication
    public typealias ZViewController = NSViewController


#elseif os(iOS)


    import UIKit
    import CoreData


    public typealias ZFont           = UIFont
    public typealias ZView           = UIView
    public typealias ZColor          = UIColor
    public typealias ZApplication    = UIApplication
    public typealias ZViewController = UIViewController


    extension ZApplication {
        func presentError(error: NSError) -> Void {

        }
    }


    extension NSManagedObjectContext {
        func commitEditing() -> Bool {
            return true
        }
    }


#endif
