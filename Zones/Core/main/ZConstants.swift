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


let userTouchLength: CGFloat = 33.0
let      widgetFont:   ZFont = ZFont.systemFont(ofSize: fontSize)
let       controllersManager = ZControllersManager()
let        operationsManager = ZOperationsManager()
let         selectionManager = ZSelectionManager()
let           widgetsManager = ZWidgetsManager()
let           editingManager = ZEditingManager()
let            travelManager = ZTravelManager()
let             cloudManager = ZCloudManager()
let             zfileManager = ZFileManager()
let               mainWindow = ZoneWindow.window
let                  cloudID = "iCloud.com.zones.Zones"
let                 linksKey = "links"
let              zoneTypeKey = "Zone"
let              rootNameKey = "root"
let              childrenKey = "children"
let              zoneNameKey = "zoneName"
let            recordNameKey = "recordName"
let            recordTypeKey = "recordType"
let           storageModeKey = "storageMode"
let          showChildrenKey = "showChildren"


enum ZSynchronizationState: Int {
    case cloud
    case restore
    case root
    case fetch
    case children
    case unsubscribe
    case subscribe
    case ready
    case merge
    case flush
}


enum ZControllerID: Int {
    case editor
    case tools
    case main
    case editingTools
    case settings
    case travel
}


enum ZUpdateKind: Int {
    case data
    case datum
    case error
    case delete
}


enum ZStorageMode: String {
    case bookmarks = "bookmarks"
    case everyone  = "everyone"
    case group     = "group"
    case mine      = "mine"
}


enum ZEditMode: Int {
    case task
    case essay
}


enum ZTravelAction: Int {
    case bookmarks
    case everyone
    case mine
}


enum ZLineKind: Int {
    case below    = -1
    case straight =  0
    case above    =  1
}


enum ZArrowKey: CChar {
    case up    = -128
    case down
    case left
    case right
}


struct ZRecordState: OptionSet {
    let rawValue: Int

    static let ready         = ZRecordState(rawValue:      0)
    static let needsSave     = ZRecordState(rawValue: 1 << 0)
    static let needsFetch    = ZRecordState(rawValue: 1 << 1)
    static let needsMerge    = ZRecordState(rawValue: 1 << 2)
    static let needsDelete   = ZRecordState(rawValue: 1 << 3)
    static let needsCreate   = ZRecordState(rawValue: 1 << 4)
    static let needsChildren = ZRecordState(rawValue: 1 << 5)
}
