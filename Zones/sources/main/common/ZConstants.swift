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

let kIsDesktop                   = true
let kIsPhone                     = false
let kUnselectBrightness: CGFloat = 0.93

#elseif os(iOS)

    import UIKit

let kIsDesktop                   = false
let kIsPhone                     = UIDevice.current.userInterfaceIdiom == .phone
let kUnselectBrightness: CGFloat = 0.98

#endif


let         kBatchSize = 250
let        kLogTabStop = 21
let      kMaxBatchSize = 1000
let     kRemoteTimeout = 10.0
let    kReductionRatio = CGFloat(0.8)
let  kDefaultZoneColor = ZColor.blue

let       gUndoManager = UndoManager()

let            kNoName = "empty"
let           kCloudID = "iCloud.com.zones.Zones"
let          kNullLink = "no"
let         kTrashLink = kSeparator + kSeparator + "trash"
let  kHalfLineOfDashes = "-----------"
let kLineWithStubTitle = kHalfLineOfDashes + " | " + kHalfLineOfDashes
let   kLocalNamePrefix = "local."
let    kLocalOnlyNames = [kTrashName, kFavoriteRootName]
let      kLineOfDashes = kHalfLineOfDashes + "---" + kHalfLineOfDashes
let         kRootNames = [kRootName] + kLocalOnlyNames


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
let     kGenericOffset = "generic offset"
let      kUserRecordID = "user record id"
let      kScrollOffset = "scroll offset"
let       kStorageMode = "current storage mode"
let        kCountsMode = "counts mode"
let         kBackspace = "\u{8}"
let         kThickness = "line thickness"
let           kScaling = "scaling"
let            kDelete = "\u{7F}"
let             kSpace = " "
let               kTab = "\t"
