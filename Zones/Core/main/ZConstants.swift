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


enum ZArrowKey: CChar {
    case up    = -128
    case down
    case left
    case right
}


let userTouchLength: CGFloat = 33.0
let      widgetFont:   ZFont = ZFont.systemFont(ofSize: fontSize)
let       controllersManager = ZControllersManager()
let        operationsManager = ZOperationsManager()
let         bookmarksManager = ZBookmarksManager()
let         selectionManager = ZSelectionManager()
let           widgetsManager = ZWidgetsManager()
let           editingManager = ZEditingManager()
let            travelManager = ZTravelManager()
let             cloudManager = ZCloudManager()
let             zfileManager = ZFileManager()
let               mainWindow = ZoneWindow.window!
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
let          manifestTypeKey = "ZManifest"
let          manifestNameKey = "manifest"
