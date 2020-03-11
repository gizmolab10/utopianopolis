//
//  ZConstants.swift
//  Thoughtful
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


let                 kBatchSize = 250
let                kLogTabStop = 25
let              kMaxBatchSize = 1000
let             kRemoteTimeout = 10.0
let            kSmallBatchSize = 100
let  kDefaultEssayTextFontSize = CGFloat(18.0)
let kDefaultEssayTitleFontSize = CGFloat(24.0)
let       kTimeOfSystemStartup = Date.timeIntervalSinceReferenceDate
let        kFavoritesReduction = CGFloat(kIsPhone ? 1.0 : 0.8)
let         kDefaultWindowRect = CGRect(x:0.0, y:0.0, width: 500.0, height: 500.0) // smallest size user to which can shrink window
let          kDefaultZoneColor = ZColor.blue
let                 kGridColor = ZColor.darkGray
let                kClearColor = ZColor.clear
let                kWhiteColor = ZColor.white
let               kUndoManager = UndoManager()

let                 kTrashLink = kNameSeparator + kNameSeparator + kTrashName
let          kLostAndFoundLink = kNameSeparator + kNameSeparator + kLostAndFoundName
let          kHalfLineOfDashes = "-----------"
let         kLineWithStubTitle = kHalfLineOfDashes + " | " + kHalfLineOfDashes
let        kAutoGeneratedNames = [kTrashName, kFavoritesRootName, kLostAndFoundName]
let              kLineOfDashes = kHalfLineOfDashes + "---" + kHalfLineOfDashes
let                 kRootNames = [kRootName] + kAutoGeneratedNames
let                  kExitKeys = [kReturn, "f", kEscape]


let kAllDatabaseIDs: [ZDatabaseID] = [.mineID, .everyoneID]


// MARK:- property names
// MARK:-


let                    kpEssay = "essay"
let                    kpOwner = "owner"
let                   kpParent = "parent"
let                 kpZoneName = "zoneName"
let                 kpZoneLink = "zoneLink"
let                kpZoneCount = "zoneCount"
let                kpZoneLevel = "zoneLevel"
let               kpZonePrefix = "zone"
let               kpRecordName = "recordName"
let             kpRecordPrefix = "record"
let           kpZoneParentLink = "parentLink"
let         kpModificationDate = "modificationDate"


// MARK:- strings and dictionary keys
// MARK:-


let                       kTab = "\t"
let                      kStop = "stop"
let                     kStops = "stops"
let                     kSpace = " "
let                     kLinks = "links"
let                    kReturn = "\r"
let                    kDelete = "\u{7F}"
let                    kEscape = "\u{1B}"
let                   kNoValue = "empty"
let                   kScaling = "scaling"
let                   kCloudID = "iCloud.com.zones.Zones"
let                  kAuthorID = "author id"
let                  kUseCloud = "use cloud"
let                  kUserType = CKRecord.SystemType.userRecord
let                  kZoneType = "Zone"
let                  kRootName = "root"
let                  kNullLink = "no"
let                  kEllipsis = "\u{2026}"
let                  kLocation = "location"
let                  kWorkMode = "work mode"
let                 kEmptyIdea = "idea"
let                 kAlignment = "alignment"
let                 kThickness = "line thickness"
let                 kTraitType = "ZTrait"
let                 kTrashName = "trash"
let                 kBackspace = "\u{8}"
let                 kFullFetch = "full fetch"
let                kDatabaseID = "current database identifier"
let                kCountsMode = "counts mode"
let               kMathewStyle = "mathew schreiber style UI"
let               kCurrentNote = "current note"
let 			 kEssayDefault = "Begin writing your thoughts"
let              kCurrentGraph = "current graph"
let              kManifestType = "ZManifest"
let              kBrowsingMode = "browsing mode"
let              kCurrentEssay = "current essay"
let              kTimeInterval = "TimeInterval"
let              kDetailsState = "current details state"
let              kDebugDetails = "debug details"
let              kUserRecordID = "user record id"
let              kRingContents = "ring contents"
let             kWindowRectKey = "window rect"
let             kHereRecordIDs = "here record ids"
let             kExpandedZones = "expanded zones"
let             kShowFavorites = "show favorites"
let             kFavoritesName = "favorites"
let             kInsertionMode = "graph altering mode"
let            kActionFunction = "current action function"
let            kInvertColorize = "c"
let            kEmailTypesSent = "email types sent"
let            kFirstIdeaTitle = "I can click HERE to edit my first idea"
let           kScrollOffsetKey = "scroll offset"
let           kFavoritesSuffix = " favorite"
let           kCurrentFavorite = "current favorite"
let           kClipBreadcrumbs = "clip breadcrumbs"
let          kGenericOffsetKey = "generic offset"
let          kAssumeAllFetched = "assume all fetched"
let          kLostAndFoundName = "lost and found"
let         kFavoritesRootName = "favorites"
let         kTriangleImageName = "yangle.png"
let         kHelpMenuImageName = "help.menu"
let         kMarkingCharacters = "0123456789x_*#$@%^&!?"
let         kFullRingIsVisible = "full ring is visible"
let        kShowAllBreadcrumbs = "show all breadcrumbs"
let        kEssayTitleFontSize = "essay title font size"
let        kRubberbandColorKey = "rubberband color"
let        kBackgroundColorKey = "background color"
let        kTutorialRecordName = "note:96689264-EB25-49CC-9324-913BA5CEBD56"
let       kProductionEmailSent = "production email sent"
let     kToolTipsAlwaysVisible = "tool tips always visible"
let    kFavoritesAreVisibleKey = "favorites are visible"

let             kNameSeparator = ":"
let            kCrumbSeparator = "      "
let           kSearchSeparator = ":1:2:"
let         kLevelOneSeparator = "  ((a))  "
let         kLevelTwoSeparator = " (a|a) "
let       kLevelThreeSeparator = " (f) "
let        kLevelFourSeparator = " (v) "
