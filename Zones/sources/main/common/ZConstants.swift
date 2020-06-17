//
//  ZConstants.swift
//  Seriously
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

let                 kRingWidth = 130.0
let                 kBatchSize = 250
let                kLogTabStop = 25
let              kMaxBatchSize = 1000
let              kDetailsWidth = 226.0
let             kRemoteTimeout = 10.0
let            kSmallBatchSize = 100
let          kHalfDetailsWidth = kDetailsWidth / 2.0
let  kDefaultEssayTextFontSize = CGFloat(18.0)
let kDefaultEssayTitleFontSize = CGFloat(24.0)
let       kTimeOfSystemStartup = Date.timeIntervalSinceReferenceDate
let        kFavoritesReduction = CGFloat(kIsPhone ? 1.0 : 0.8)
let         kDefaultWindowRect = CGRect(x:0.0, y:0.0, width: 500.0, height: 500.0) // smallest size user to which can shrink window
let         kLightestGrayColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.8, alpha: 1.0)
let          kDarkestGrayColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.1, alpha: 1.0)
let            kLightGrayColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.7, alpha: 1.0)
let             kDarkGrayColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.6, alpha: 1.0)
let                kWhiteColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 1.0, alpha: 1.0)
let                kBlackColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.0, alpha: 1.0)
let                kClearColor = ZColor.clear
let                 kBlueColor = ZColor.blue
let                 kGridColor = ZColor.darkGray
let               gUndoManager = UndoManager()

let                 kTrashLink = kColonSeparator + kColonSeparator + kTrashName
let          kLostAndFoundLink = kColonSeparator + kColonSeparator + kLostAndFoundName
let          kHalfLineOfDashes = "-----------"
let         kLineWithStubTitle = kHalfLineOfDashes + " | " + kHalfLineOfDashes
let        kAutoGeneratedNames = [kTrashName, kDestroyName, kExemplarName, kRecentsRootName, kFavoritesRootName, kLostAndFoundName]
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

let                     kLinks = "links"
let                     kStops = "stops"
let                      kStop = "stop"
let                       kTab = "\t"
let                     kSpace = " "
let                    kEquals = "="
let                    kReturn = "\r"
let                    kDelete = "\u{7F}"
let                    kEscape = "\u{1B}"
let                   kNoValue = "empty"
let                   kScaling = "scaling"
let                   kUnknown = "unknown"
let                   kClickTo = "Click to "
let                   kCloudID = "iCloud.com.zones.Zones"
let                  kUserType = CKRecord.SystemType.userRecord
let                  kWorkMode = "working mode"
let                  kAuthorID = "author id"
let                  kUseCloud = "use cloud"
let                  kZoneType = "Zone"
let                  kRootName = "root"
let                  kNullLink = "no"
let                  kEllipsis = "\u{2026}"
let                  kLocation = "location"
let                 kEmptyIdea = "idea"
let                 kTrashName = "trash"
let                 kBackspace = "\u{8}"
let                 kTraitType = "ZTrait"
let                 kAlignment = "alignment"
let                 kFullFetch = "full fetch"
let                 kThickness = "line thickness"
let                kDatabaseID = "current database identifier"
let                kSkillLevel = "power user mode"
let                kUserRecord = "user record"
let                kCountsMode = "counts mode"
let               kDestroyName = "destroy"
let               kRecentsName = "recents"
let               kCurrentNote = "current note"
let         	 kEssayDefault = "Begin writing your thoughts"
let              kDetailsState = "current details state"
let              kShowToolTips = "show tool tips"
let              kUserRecordID = "user record id"
let              kStartupLevel = "startup level"
let              kCurrentGraph = "current graph"
let              kColorfulMode = "colorful mode"
let              kCurrentEssay = "current essay"
let              kDebugDetails = "debug details"
let              kTimeInterval = "TimeInterval"
let              kManifestType = "ZManifest"
let              kExemplarName = "exemplar"
let             kFavoritesName = "favorites"
let             kWindowRectKey = "window rect"
let             kExpandedZones = "expanded zones"
let             kShowFavorites = "show favorites" // for iphone
let             kHereRecordIDs = "here record ids"
let             kFavoritesMode = "favorites or recent"
let            kListGrowthMode = "list growth direction"
let            kFirstIdeaTitle = "I can click HERE to edit my first idea"
let            kActionFunction = "current action function"
let            kEmailTypesSent = "email types sent"
let            kAccentColorKey = "accent color"
let            kActiveColorKey = "active color"
let            kInvertColorize = "c"
let           kRecentsRootName = "recents"
let           kFavoritesSuffix = " favorite"
let           kScrollOffsetKey = "scroll offset"
let           kCurrentFavorite = "current favorite"
let           kClipBreadcrumbs = "clip breadcrumbs"
let           kConfinementMode = "confinement mode"
let          kOrignalImageName = "original image name"
let          kAssumeAllFetched = "assume all fetched"
let 		 kGenericOffsetKey = "generic offset"
let          kLostAndFoundName = "lost and found"
let         kFavoritesRootName = "favorites"
let         kHelpMenuImageName = "help.menu"
let         kTriangleImageName = "yangle.png"
let         kMarkingCharacters = "0123456789x_*#$@%^&!?"
let         kEnabledCloudDrive = "enabled cloud drive"
let        kEssayTitleFontSize = "essay title font size"
let        kHasAccessToAppleID = "has access to apple id"
let        kTutorialRecordName = "essay:96689264-EB25-49CC-9324-913BA5CEBD56"
let       kCloudDriveIsEnabled = "cloud drive is enabled"
let       kProductionEmailSent = "production email sent"
let      kLastChosenCheatSheet = "last chosen cheat sheet"
let    kFavoritesAreVisibleKey = "favorites are visible"
let  kUnderstandsNeedForAccess = "understands need for access to apple id"

let            kColonSeparator = ":"
let            kCommaSeparator = ","
let            kCrumbSeparator = "      "
let           kSearchSeparator = ":1:2:"
let         kLevelOneSeparator = "  ((a))  "
let         kLevelTwoSeparator = " (a|a) "
let       kLevelThreeSeparator = " (f) "
let        kLevelFourSeparator = " (v) "
