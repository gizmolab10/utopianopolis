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


let          kBatchSize = 250
let         kLogTabStop = 21
let       kMaxBatchSize = 1000
let      kRemoteTimeout = 10.0
let     kSmallBatchSize = 100
let     kReductionRatio = CGFloat(0.8)
let   kDefaultZoneColor = ZColor.blue
let         kClearColor = ZColor(white: 1.0, alpha: 0.0)
let        kUndoManager = UndoManager()

let          kTrashLink = kSeparator + kSeparator + kTrashName
let   kLostAndFoundLink = kSeparator + kSeparator + kLostAndFoundName
let   kHalfLineOfDashes = "-----------"
let  kLineWithStubTitle = kHalfLineOfDashes + " | " + kHalfLineOfDashes
let kAutoGeneratedNames = [kTrashName, kFavoritesRootName, kLostAndFoundName]
let       kLineOfDashes = kHalfLineOfDashes + "---" + kHalfLineOfDashes
let          kRootNames = [kRootName] + kAutoGeneratedNames


// MARK:- property names
// MARK:-


let             kpOwner = "owner"
let            kpParent = "parent"
let          kpZoneName = "zoneName"
let          kpZoneLink = "zoneLink"
let         kpZoneCount = "zoneCount"
let         kpZoneLevel = "zoneLevel"
let        kpZonePrefix = "zone"
let        kpRecordName = "recordName"
let      kpRecordPrefix = "record"


// MARK:- strings and dictionary keys
// MARK:-


let                kTab = "\t"
let              kSpace = " "
let              kLinks = "links"
let             kNoName = "empty"
let             kDelete = "\u{7F}"
let             kEscape = "\u{1B}"
let            kScaling = "scaling"
let            kCloudID = "iCloud.com.zones.Zones"
let           kUseCloud = "use cloud"
let           kZoneType = "Zone"
let           kRootName = "root"
let           kNullLink = "no"
let          kBackspace = "\u{8}"
let          kThickness = "line thickness"
let          kTraitType = "ZTrait"
let          kSeparator = ":"
let          kTrashName = "trash"
let          kFullFetch = "full fetch"
let         kCountsMode = "counts mode"
let         kWindowSize = "window size"
let         kDatabaseID = "current database identifier"
let       kTimeInterval = "TimeInterval"
let       kScrollOffset = "scroll offset"
let       kDetailsState = "current details state"
let       kDebugDetails = "debug details"
let       kUserRecordID = "user record id"
let      kHereRecordIDs = "here record ids"
let      kExpandedZones = "expanded zones"
let      kFavoritesName = "favorites"
let      kGenericOffset = "generic offset"
let      kInsertionMode = "graph altering mode"
let     kActionsVisible = "actions are visible"
let    kFavoritesSuffix = " favorite"
let    kRubberbandColor = "rubberband color"
let    kBackgroundColor = "background color"
let    kCurrentFavorite = "current favorite"
let   kLostAndFoundName = "lost and found"
let   kfavoritesVisible = "favorites are visible"
let  kFavoritesRootName = "favorites"
let  kTriangleImageName = "yangle.png"
let  kMarkingCharacters = "0123456789_*$@#%^&!x" // §∞†∆…Ω÷•

