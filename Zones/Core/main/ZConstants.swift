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

let isOSX                       = true
let fontSize:           CGFloat = 17.0
let unselectBrightness: CGFloat = 0.93
#elseif os(iOS)
    import UIKit

let isOSX                       = false
let fontSize:           CGFloat = 14.0
let unselectBrightness: CGFloat = 0.98
#endif


let             gUnlevel = -1
let       gFingerBreadth = CGFloat(33.0)
let          gWidgetFont = ZFont.systemFont(ofSize: fontSize)
let  gSelectedWidgetFont = ZFont.systemFont(ofSize: fontSize) // .boldSystemFont(ofSize: fontSize * 0.93)
let  gControllersManager = ZControllersManager()
let   gOperationsManager = ZOperationsManager()
let    gSelectionManager = ZSelectionManager()
let    gFavoritesManager = ZFavoritesManager()
let      gWidgetsManager = ZWidgetsManager()
let      gEditingManager = ZEditingManager()
let       gTravelManager = ZTravelManager()
let        gCloudManager = ZCloudManager()
let         gfileManager = ZFileManager()
let         gUndoManager = UndoManager()
let              cloudID = "iCloud.com.zones.Zones"
let             linksKey = "links"
let          zoneTypeKey = "Zone"
let          rootNameKey = "root"
let          childrenKey = "children"
let          zoneNameKey = "zoneName"
let        recordNameKey = "recordName"
let        recordTypeKey = "recordType"
let      showChildrenKey = "showChildren"
let      manifestTypeKey = "ZManifest"
let      manifestNameKey = "manifest"
let favoritesRootNameKey = "favoritesRoot"

var     gHere:      Zone { get { return gManifest.hereZone } set { gManifest.hereZone = newValue } }
var gManifest: ZManifest { return gTravelManager.manifest }
