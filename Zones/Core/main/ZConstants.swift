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

    let fontSize:           CGFloat = 17.0
    let unselectBrightness: CGFloat = 0.93
#elseif os(iOS)
    import UIKit

    let fontSize:           CGFloat = 14.0
    let unselectBrightness: CGFloat = 0.98
#endif


enum ZSynchronizationState: Int {
    case restore
    case root
    case unsubscribe
    case subscribe
    case ready
}


enum ZUpdateKind: UInt {
    case data
    case error
    case delete
}


enum RecordState: Int {
    case needsFetch
    case needsSave
    case ready
}


enum ZToolMode: Int {
    case settings
    case edit
    case travel
}


enum ZEditAction: UInt {
    case add
    case delete
    case moveUp
    case moveDown
}


let userTouchLength: CGFloat = 33.0

let       stateManager = ZStateManager()
let       cloudManager = ZCloudManager()
let       zonesManager = ZonesManager()
let persistenceManager = ZLocalPersistenceManager()
let  widgetFont: ZFont = ZFont.systemFont(ofSize: fontSize)
let            cloudID = "iCloud.com.zones.Zones"
let    showChildrenKey = "showChildren"
let      recordNameKey = "recordName"
let      recordTypeKey = "recordType"
let        childrenKey = "children"
let        zoneNameKey = "zoneName"
let        zoneTypeKey = "Zone"
let        rootNameKey = "root"
let           linksKey = "links"
