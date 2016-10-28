//
//  ZConstants.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZActionKind: UInt {
    case add
    case delete
    case moveUp
    case moveDown
    case toggleVisibility
}


enum ZUpdateKind: UInt {
    case data
    case error
    case delete
}


enum ZToolState: Int {
    case edit
    case travel
    case layout
}


enum ZSynchronizationState: Int {
    case restore
    case root
    case unsubscribe
    case subscribe
    case ready
}


let       stateManager = ZStateManager()
let       modelManager = ZModelManager()
let persistenceManager = ZLocalPersistenceManager()
let  widgetFont: ZFont = ZFont.userFont(ofSize: 17.0)!
let            cloudID = "iCloud.com.zones.Zones"
let    showChildrenKey = "showChildren"
let      recordNameKey = "recordName"
let      recordTypeKey = "recordType"
let        childrenKey = "children"
let        zoneNameKey = "zoneName"
let        zoneTypeKey = "Zone"
let        rootNameKey = "root"
let         parentsKey = "parents"
let           linksKey = "links"


#if os(OSX)

let zapplication = ZApplication.shared()

#elseif os(iOS)

let zapplication = ZApplication.shared

#endif
