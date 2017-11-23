//
//  ZConstants.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


#if os(OSX)

    import Cocoa

let isOSX                       = true
let isPhone                     = false
let unselectBrightness: CGFloat = 0.93

#elseif os(iOS)

    import UIKit

let isOSX                       = false
let isPhone                     = UIDevice.current.userInterfaceIdiom == .phone
let unselectBrightness: CGFloat = 0.98

#endif


let       gRemoteTimeout = 10.0
let          gLogTabStop = 21
let           gBatchSize = 250
let             gUnlevel = -1
let             fontSize = CGFloat(17.0)
let          gWidgetFont = ZFont.systemFont(ofSize: fontSize)
let       gFavoritesFont = ZFont.systemFont(ofSize: fontSize * gReductionRatio)
let       gFingerBreadth = CGFloat(44.0)
let      gReductionRatio = CGFloat(0.8)
let    gDefaultZoneColor = ZColor.blue

let         gUndoManager = UndoManager()

let             gCloudID = "iCloud.com.zones.Zones"
let            gLinksKey = "links"
let            gNullLink = "no"
let           gTrashLink = "\(gSeparatorKey)\(gSeparatorKey)trash"
let         gZoneTypeKey = "Zone"
let         gRootNameKey = "root"
let         gChildrenKey = "children"
let         gZoneNameKey = "zoneName"
let        gSeparatorKey = ":"
let        gTrashNameKey = "trash"
let        gFavoritesKey = "favorites"
let       gRecordNameKey = "recordName"
let       gRecordTypeKey = "recordType"
let     gShowChildrenKey = "showChildren"
let     gManifestTypeKey = "ZManifest"
let gFavoriteRootNameKey = "favoritesRoot"
let    gHalfLineOfDashes = "-----------"
let   gLineWithStubTitle = gHalfLineOfDashes + " | " + gHalfLineOfDashes
let        gLineOfDashes = gHalfLineOfDashes + "---" + gHalfLineOfDashes

let        gBackspaceKey = "\u{8}"
let           gDeleteKey = "\u{7F}"
let            gSpaceKey = " "
let              gTabKey = "\t"
