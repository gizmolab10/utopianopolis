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


let           gUnlevel = -1
let         gBatchSize = 250
let        gLogTabStop = 21
let     gRemoteTimeout = 10.0
let     gFingerBreadth = CGFloat(44.0)
let    gReductionRatio = CGFloat(0.8)
let  gDefaultZoneColor = ZColor.blue

let       gUndoManager = UndoManager()

let            gNoName = "empty"
let           gCloudID = "iCloud.com.zones.Zones"
let          gNullLink = "no"
let         gTrashLink = kSeparator + kSeparator + "trash"
let  gHalfLineOfDashes = "-----------"
let gLineWithStubTitle = gHalfLineOfDashes + " | " + gHalfLineOfDashes
let   gLocalNamePrefix = "local."
let    gLocalOnlyNames = [kTrashName, kFavoriteRootName]
let      gLineOfDashes = gHalfLineOfDashes + "---" + gHalfLineOfDashes
let         gRootNames = [kRootName] + gLocalOnlyNames


// MARK:- keys
// MARK:-


let             kLinks = "links"
let          kRootName = "root"
let          kChildren = "children"
let          kZoneName = "zoneName"
let          kZoneType = "Zone"
let         kTraitType = "ZTrait"
let         kSeparator = ":"
let         kTrashName = "trash"
let        kRecordName = "recordName"
let        kRecordType = "recordType"
let      kShowChildren = "showChildren"
let      kManifestType = "ZManifest"
let     kFavoritesName = "favorites"
let  kFavoriteRootName = "favoritesRoot"
let  kfavoritesVisible = "favorites are visible"
let   kRubberbandColor = "rubberband color"
let   kBackgroundColor = "background color"
let   kCurrentFavorite = "current favorite"
let    kActionsVisible = "actions are visible"
let     kSettingsState = "current settings state"
let     kInsertionMode = "graph altering mode"
let     kLineThickness = "line thickness"
let     kGenericOffset = "generic offset"
let      kUserRecordID = "user record id"
let      kScrollOffset = "scroll offset"
let       kStorageMode = "current storage mode"
let        kCountsMode = "counts mode"
let         kBackspace = "\u{8}"
let           kScaling = "scaling"
let            kDelete = "\u{7F}"
let             kSpace = " "
let               kTab = "\t"
