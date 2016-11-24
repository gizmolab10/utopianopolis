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
let         bookmarksManager = ZBookmarksManager()
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
    case restore
    case root
    case fetch
    case unsubscribe
    case subscribe
    case ready
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


enum ZRecordState: Int {
    case needsCreating // record is nil
    case needsDelete
    case needsFetch
    case needsSave
    case ready
}


enum ZStorageMode: String {
    case everyone = "everyone"
    case group    = "group"
    case mine     = "mine"
}


enum ZToolMode: Int {
    case settings
    case edit
    case travel
}


enum ZEditMode: Int {
    case task
    case essay
}


enum ZEditAction: Int {
    case add
    case delete
    case moveUp
    case moveDown
    case moveToParent
    case moveIntoSibling
}


enum ZTravelAction: Int {
    case mine
    case everyone
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


struct ZKeyModifierFlags: OptionSet {
    let rawValue: Int

    static let none    = ZKeyModifierFlags(rawValue: 0)
    static let shift   = ZKeyModifierFlags(rawValue: 1)
    static let option  = ZKeyModifierFlags(rawValue: 2)
    static let command = ZKeyModifierFlags(rawValue: 4)
}
