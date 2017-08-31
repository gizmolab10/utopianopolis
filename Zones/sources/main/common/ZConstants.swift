//
//  ZConstants.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
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
let          gLogTabStop = 15
let          gWidgetFont = ZFont.systemFont(ofSize: fontSize)
let       gFavoritesFont = ZFont.systemFont(ofSize: fontSize * gReductionRatio)
let       gFingerBreadth = CGFloat(33.0)
let      gReductionRatio = CGFloat(0.8)
let    gDefaultZoneColor = ZColor.blue

let  gControllersManager = ZControllersManager()
let   gOperationsManager = ZOperationsManager()
let    gSelectionManager = ZSelectionManager()
let    gFavoritesManager = ZFavoritesManager(.favorites)
let      gWidgetsManager = ZWidgetsManager()
let      gEditingManager = ZEditingManager()
let       gTravelManager = ZTravelManager()
let         gFileManager = ZFileManager()
let         gUndoManager = UndoManager()

let              cloudID = "iCloud.com.zones.Zones"
let             linksKey = "links"
let          zoneTypeKey = "Zone"
let          rootNameKey = "root"
let          childrenKey = "children"
let          zoneNameKey = "zoneName"
let         trashNameKey = "trash"
let        recordNameKey = "recordName"
let        recordTypeKey = "recordType"
let      showChildrenKey = "showChildren"
let      manifestTypeKey = "ZManifest"
let      manifestNameKey = "manifest"
let favoritesRootNameKey = "favoritesRoot"

let        gBackspaceKey = "\u{8}"
let           gDeleteKey = "\u{7F}"
let            gSpaceKey = " "
let              gTabKey = "\t"
