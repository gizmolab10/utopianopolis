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

let                    kOneDay = kOneHour * 24
let                   kOneHour = kOneMinute * 60
let                   kOneYear = kOneDay * 365
let                  kOneMonth = kOneDay * 30
let                 kRingWidth = 130.0
let                 kBatchSize = 250
let                 kOneMinute = 60
let                kLogTabStop = 25
let              kMaxBatchSize = 1000
let              kDetailsWidth = 226.0
let             kRemoteTimeout = 10.0
let            kSmallBatchSize = 125
let            kFileRecordSize = 1040
let          kOneTimerInterval = 1.0 / 5.0
let          kHalfDetailsWidth = kDetailsWidth / 2.0
let  kDefaultEssayTextFontSize = CGFloat(18.0)
let kDefaultEssayTitleFontSize = CGFloat(24.0)
let      kDevelopmentStartDate = Date(timeIntervalSinceReferenceDate: 14.0 * 365.0 * 24.0 * 60.0 * 16.0) // jan 1 2015
let       kTimeOfSystemStartup = Date.timeIntervalSinceReferenceDate
let         kSmallMapReduction = CGFloat(kIsPhone ? 1.0 : 0.8)
let         kDefaultWindowRect = CGRect(x:0.0, y:0.0, width: 500.0, height: 500.0) // smallest size user to which can shrink window
let         kLightestGrayColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.85, alpha: 1.0)
let          kLighterGrayColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.8,  alpha: 1.0)
let          kDarkestGrayColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.1,  alpha: 1.0)
let           kDarkerGrayColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.2,  alpha: 1.0)
let            kLightGrayColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.7,  alpha: 1.0)
let             kDarkGrayColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.6,  alpha: 1.0)
let                kWhiteColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 1.0,  alpha: 1.0)
let                kBlackColor = ZColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.0,  alpha: 1.0)
let                kSystemBlue = NSColor(cgColor: ZColor.systemBlue.cgColor)!
let          kDefaultIdeaColor = kSystemBlue
let                kClearColor = ZColor.clear
let                 kGrayColor = ZColor.gray
let                 kGridColor = ZColor.darkGray
let               gUndoManager = UndoManager()

let                 kTrashLink = kColonSeparator + kColonSeparator + kTrashName
let               kDestroyLink = kColonSeparator + kColonSeparator + kDestroyName
let          kLostAndFoundLink = kColonSeparator + kColonSeparator + kLostAndFoundName
let          kHalfLineOfDashes = "-----------"
let         kLineWithStubTitle = kHalfLineOfDashes + " | " + kHalfLineOfDashes
let        kAutoGeneratedNames = [kTrashName, kDestroyName, kLostAndFoundName, kTemplatesRootName, kRecentsRootName, kFavoritesRootName, kExemplarRootName]
let              kLineOfDashes = kHalfLineOfDashes + "---" + kHalfLineOfDashes
let                 kRootNames = [kRootName] + kAutoGeneratedNames
let                  kExitKeys = [kReturn, "f", kEscape]

let kAllDatabaseIDs: [ZDatabaseID] = [.mineID, .everyoneID]

// MARK:- property names
// MARK:-

let                     kpDBID = "dbid"
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
let                     kLinks = "links"
let                     kStops = "stops"
let                     kEmpty = ""
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
let                  kUserType = "ZUser"
let                  kWorkMode = "working mode"
let                  kAuthorID = "author id"
let                  kUseCloud = "use cloud"
let                  kLocation = "location"
let                  kEllipsis = "\u{2026}"
let                  kOwnerRef = "ownerRef"
let                  kFileType = "ZFile"
let                  kZoneType = "Zone"
let                  kNullLink = "no"
let                  kRootName = "root"
let                 kRootsName = "roots"
let                 kBackSlash = "\\"
let                 kEmptyIdea = "idea"
let                 kTrashName = "trash"
let                 kBackspace = "\u{8}"
let                 kTraitType = "ZTrait"
let                 kParentRef = "parentRef"
let                 kAlignment = "alignment"
let                 kSubscribe = "Subscribe"
let                 kFullFetch = "full fetch"
let                 kThickness = "line thickness"
let                 kUsersType =  CKRecord.SystemType.userRecord
let                kDatabaseID = "current database identifier"
let                kUserRecord = "user record"
let                kCountsMode = "counts mode"
let                kCurrentMap = "current map"
let                kChildArray = "childArray"
let                kTraitArray = "traitArray"
let               kDoubleQuote = "\""
let               kDestroyName = "destroy"
let               kCurrentNote = "current note"
let               kShowDetails = "show details"
let         	 kEssayDefault = "Begin writing your thoughts"
let              kDetailsState = "current details state"
let              kSubscription = "My Subscription"
let              kSmallMapMode = "small map mode"
let              kShowSmallMap = "show small map" // for iphone
let              kShowToolTips = "show tool tips"
let              kFilterOption = "filter option"
let              kStartupLevel = "startup level"
let              kColorfulMode = "colorful mode"
let              kCurrentEssay = "current essay"
let              kDebugDetails = "debug details"
let              kTimeInterval = "TimeInterval"
let              kManifestType = "ZManifest"
let             kWindowRectKey = "window rect"
let             kProgressTimes = "progressTimes"
let             kExpandedZones = "expanded zones"
let            kFirstIdeaTitle = "please click HERE to edit this idea"
let            kActionFunction = "current action function"
let            kListGrowthMode = "list growth direction"
let            kEmailTypesSent = "email types sent"
let            kUserRecordName = "user record id"
let            kAccentColorKey = "accent color"
let            kActiveColorKey = "active color"
let            kUserRecordType = "Users"
let            kUserEntityName = "ZUser"
let           kScratchRootName = "scratch"
let           kRecentsRootName = "recents"
let           kFavoritesSuffix = " favorite"
let           kTraitAssetsType = "ZTraitAssets"
let           kScrollOffsetKey = "scroll offset"
let           kHereRecordNames = "here record ids"
let           kCurrentFavorite = "current favorite"
let           kClipBreadcrumbs = "clip breadcrumbs"
let           kConfinementMode = "confinement mode"
let           kShowEssayTitles = "show essay titles"
let          kOrignalImageName = "original image name"
let          kAssumeAllFetched = "assume all fetched"
let 		 kGenericOffsetKey = "generic offset"
let          kLostAndFoundName = "lost and found"
let          kManifestRootName = "manifest"
let          kExemplarRootName = "exemplar"
let          kNoteIndentSpacer = "  "
let         kTemplatesRootName = "templates"
let         kFavoritesRootName = "favorites"
let         kHelpMenuImageName = "help.menu"
let         kTriangleImageName = "yangle.png"
let         kNeedsMigrationKey = "needs migration"
let         kSubscriptionToken = "subscription token"
let         kMarkingCharacters = "0123456789_*$@%^&!?"
let         kEnabledCloudDrive = "enabled cloud drive"
let        kEssayTitleFontSize = "essay title font size"
let        kHasAccessToAppleID = "has access to apple id"
let        kTutorialRecordName = "essay:96689264-EB25-49CC-9324-913BA5CEBD56"
let       kCloudDriveIsEnabled = "cloud drive is enabled"
let       kProductionEmailSent = "production email sent"
let       kShowMySubscriptions = "show my subscriptions"
let      kSmallMapIsVisibleKey = "small map is visible"
let      kLastChosenCheatSheet = "last chosen cheat sheet"
let  kUnderstandsNeedForAccess = "understands need for access to apple id"

let              kDotSeparator = "."
let            kColonSeparator = ":"
let            kCommaSeparator = ","
let            kCrumbSeparator = "      "
let           kSearchSeparator = ":1:2:"
let         kLevelOneSeparator = "  ((a))  "
let         kLevelTwoSeparator = " (a|a) "
let       kLevelThreeSeparator = " (f) "
let        kLevelFourSeparator = " (v) "
let   kArrayTransformSeparator = "] . ["
