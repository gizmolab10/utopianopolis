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

let                        kPI = Double.pi
let                       k2PI = kPI           * 2.0
let                    kHalfPI = kPI           / 2.0
let                    kOneDay = kOneHour      *  24
let                   kOneHour = kOneMinute    *  60
let                   kOneWeek = kOneDay       *   7
let                   kOneYear = kOneDay       * 365
let                  kOneMonth = kOneYear      /  12
let          kHalfDetailsWidth = kDetailsWidth / 2.0
let                 kRingWidth =  130.0
let                 kBatchSize =  250
let                 kOneMinute =   60
let                kLogTabStop =   25
let              kMaxBatchSize = 1000
let              kDetailsWidth =  226.0
let             kRemoteTimeout =   10.0
let            kSmallBatchSize =  125
let            kFileRecordSize = 1040
let          kOneHoverInterval =    0.2
let        kOneStartupInterval =    0.67
let      kDefaultLineThickness =    1.25
let      kDefaultHorizontalGap =   30.0
let          kDefaultDotHeight = ((kDefaultFontSize + kFontDelta) / kDotFactor) + 2.0
let           kDefaultFlatness = CGFloat( 0.00001)
let          kDragDotReduction = CGFloat( 0.75)
let         kSmallMapReduction = CGFloat(kIsPhone ? 1.0 : 0.5)
let       kDefaultBaseFontSize = CGFloat( 9.0)
let       kEssayImageDotRadius = CGFloat( 5.0)
let  kDefaultEssayTextFontSize = CGFloat(18.0)
let kDefaultEssayTitleFontSize = CGFloat(24.0)
let      kDevelopmentStartDate = Date(timeIntervalSinceReferenceDate: 14.0 * 365.0 * 24.0 * 60.0 * 16.0) // jan 1 2015
let       kTimeOfSystemStartup = Date.timeIntervalSinceReferenceDate
let         kDefaultWindowRect = CGRect(x:.zero, y:.zero, width: 500.0, height: 500.0) // smallest size user to which can shrink window
let         kLightestGrayColor = ZColor(calibratedHue: .zero, saturation: .zero, brightness: 0.85,  alpha: 1.0)
let          kLighterGrayColor = ZColor(calibratedHue: .zero, saturation: .zero, brightness: 0.8,   alpha: 1.0)
let          kDarkestGrayColor = ZColor(calibratedHue: .zero, saturation: .zero, brightness: 0.1,   alpha: 1.0)
let           kDarkerGrayColor = ZColor(calibratedHue: .zero, saturation: .zero, brightness: 0.2,   alpha: 1.0)
let            kLightGrayColor = ZColor(calibratedHue: .zero, saturation: .zero, brightness: 0.7,   alpha: 1.0)
let             kDarkGrayColor = ZColor(calibratedHue: .zero, saturation: .zero, brightness: 0.6,   alpha: 1.0)
let                kWhiteColor = ZColor(calibratedHue: .zero, saturation: .zero, brightness: 1.0,   alpha: 1.0)
let                 kGrayColor = ZColor(calibratedHue: .zero, saturation: .zero, brightness: 0.5,   alpha: 1.0)
let                kBlackColor = ZColor(calibratedHue: .zero, saturation: .zero, brightness: .zero, alpha: 1.0)
let                kClearColor = ZColor(calibratedHue: .zero, saturation: .zero, brightness: .zero, alpha: .zero)
let                kSystemBlue = ZColor(cgColor: ZColor.systemBlue.cgColor)!
let                   kUpImage = ZImage(named: "up")
let                  kEyeImage = ZImage(named: "eye")
let                 kDownImage = ZImage(named: "down")
let                kStackImage = ZImage(named: "square.stack.3d.up")
let               kShowDragDot = ZImage(named: "show.drag.dot")
let               kSingleImage = ZImage(named: "minus") // square.stack.3d.up.slash.fill
let               kExpandImage = ZImage(named: "rectangle.expand.vertical")
let              kEyebrowImage = ZImage(named: "eyebrow")
let             kHelpMenuImage = ZImage(named: "help.menu")
let            kHamburgerImage = ZImage(named: "settings.jpg")
let            kLightbulbImage = ZImage(named: "lightbulb")
let           kFourArrowsImage = ZImage(named: "four.arrows")
let           kEyeglassesImage = ZImage(named: "eyeglasses")
let        kAntiLightbulbImage = ZImage(named: "lightbulb.slash.fill")
let       kSegmentDividerImage = ZImage(named: "segmented control divider.jpg")
let          kFourArrowsCursor = NSCursor.fourArrows()
let          kDefaultIdeaColor = kSystemBlue
let           kDefaultFontSize = kDefaultBaseFontSize + kFontDelta
let               gUndoManager = UndoManager()
let                 kGridColor = kDarkGrayColor

let                 kTrashLink = kColonSeparator + kColonSeparator + kTrashName
let               kDestroyLink = kColonSeparator + kColonSeparator + kDestroyName
let          kLostAndFoundLink = kColonSeparator + kColonSeparator + kLostAndFoundName
let          kHalfLineOfDashes = "-----------"
let         kLineWithStubTitle = kHalfLineOfDashes + " | " + kHalfLineOfDashes
let        kAutoGeneratedNames = [kTrashName, kDestroyName, kLostAndFoundName, kTemplatesRootName, kFavoritesRootName, kExemplarRootName]
let              kLineOfDashes = kHalfLineOfDashes + "---" + kHalfLineOfDashes
let                 kRootNames = [kRootName] + kAutoGeneratedNames

// MARK: - property names
// MARK: -

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

// MARK: - strings and dictionary keys
// MARK: -

let                       kDot = "\u{25CF}" // 233E, 25C9, 2605, 273A, 274A
let                       kTab = "\t"
let                      kDone = "done"
let                      kStop = "stop"
let                     kLists = "lists"
let                     kLinks = "links"
let                     kStops = "stops"
let                     kEmpty = ""
let                     kColon = ":"
let                     kComma = ","
let                     kSpace = " "
let                    kPeriod = "."
let                    kHyphen = "-"
let                    kEquals = "="
let                    kReturn = "\r"
let                    kDelete = "\u{7F}"
let                    kEscape = "\u{1B}"
let                    kIndent = "indent"
let                    kMailTo = "mailTo:"
let                   kNewLine = "\n"
let                   kNoValue = "empty"
let                   kScaling = "scaling"
let                   kUnknown = "unknown"
let                   kCloudID = "iCloud.com.seriously.test2"      // was iCloud.com.zones.Zones
let                  kUserType = "ZUser"
let                  kWorkMode = "working mode"
let                  kAuthorID = "author id"
let                  kUseCloud = "use cloud"
let                  kLocation = "location"
let                  kEllipsis = "\u{2026}"
let                  kOwnerRef = "ownerRef"
let                  kFileType = "ZFile"
let                  kZoneType = "Zone"
let                  kRootName = "root"
let                  kNullLink = "no"
let                 kBackSlash = "\\"
let                 kRootsName = "roots"
let                 kEmptyIdea = "idea"
let                 kTrashName = "trash"
let                 kBackspace = "\u{8}"
let                 kTraitType = "ZTrait"
let                 kSoftArrow = "\u{279C}"
let                 kParentRef = "parentRef"
let                 kAlignment = "alignment"
let                 kSubscribe = "Subscribe"
let                 kFullFetch = "full fetch"
let                 kThickness = "line thickness"
let                 kUsersType =  CKRecord.SystemType.userRecord
let                kDatabaseID = "current database identifier"
let                kTryThenBuy = "try before you buy"
let                kDebugModes = "debug modes"
let                kPrintModes = "print modes"
let                kUserRecord = "user record"
let                kCountsMode = "counts mode"
let                kCurrentMap = "current map"
let                kChildArray = "childArray"
let                kTraitArray = "traitArray"
let                kNullParent = "noParent"
let               kVerticalBar = "|"
let               kDoubleQuote = "\""
let               kDestroyName = "destroy"
let               kRecentsName = "recents"
let               kCurrentNote = "current note"
let               kShowDetails = "show details"
let              kDetailsState = "current details state"
let              kSubscription = "My Subscription"
let              kBaseFontSize = "base font size"
let              kSmallMapMode = "small map mode"
let              kShowSmallMap = "show small map" // for iphone
let              kShowToolTips = "show tool tips"
let              kCoreDataMode = "core data mode"
let              kFilterOption = "filter option"
let              kStartupLevel = "startup level"
let              kStartupCount = "startup count"
let              kColorfulMode = "colorful mode"
let              kCurrentEssay = "current essay"
let              kDebugDetails = "debug details"
let              kTimeInterval = "TimeInterval"
let              kMapOffsetKey = "map offset"
let              kManifestType = "ZManifest"
let             kControlReturn = "\u{2028}"
let             kWindowRectKey = "window rect"
let             kExpandedIdeas = "expanded zones"
let             kHorizontalGap = "horizontal gap"
let             kMapLayoutMode = "map layout mode"
let             kDoubleNewLine = kNewLine + kNewLine
let            kFirstIdeaTitle = "please click HERE to edit this idea"
let            kActionFunction = "current action function"
let            kListGrowthMode = "list growth direction"
let            kAutoLayoutMaps = "auto layout maps"
let            kEmailTypesSent = "email types sent"
let            kEssayTitleMode = "essay title mode"
let            kUserRecordName = "user record id"
let            kAccentColorKey = "accent color"
let            kActiveColorKey = "active color"
let            kCollapsedIdeas = "hidden zones"
let            kUserRecordType = "Users"
let            kUserEntityName = "ZUser"
let           kScratchRootName = "scratch"
let           kFavoritesSuffix = " favorite"
let           kTraitAssetsType = "ZTraitAssets"
let           kHereRecordNames = "here record ids1"
let           kCurrentFavorite = "current favorite"
let           kClipBreadcrumbs = "clip breadcrumbs"
let           kConfinementMode = "confinement mode"
let           kDefaultNoteText = "Please begin expanding your idea"
let          kOrignalImageName = "original image name"
let          kMapRotationAngle = "map rotation angle"
let          kAssumeAllFetched = "assume all fetched"
let          kShowMainControls = "show main controls"
let          kShowExplanations = "show explanations"
let          kLostAndFoundName = "lost and found"
let          kManifestRootName = "manifest"
let          kExemplarRootName = "exemplar"
let          kNoteIndentSpacer = "  "
let         kTemplatesRootName = "templates"
let         kFavoritesRootName = "favorites"
let         kNeedsMigrationKey = "needs migration"
let         kSubscriptionToken = "subscription token"
let         kMarkingCharacters = "0123456789_*$@%^&!?"
let         kEnabledCloudDrive = "enabled cloud drive"
let         kSearchScopeOption = "search scope option"
let        kEssayTitleFontSize = "essay title font size"
let        kHasAccessToAppleID = "has access to apple id"
let        kCirclesDisplayMode = "circles presentation mode"
let        kSubscriptionSecret = "2325a18fb3654ba38b1b8e292611d89d"
let        kTutorialRecordName = "essay:96689264-EB25-49CC-9324-913BA5CEBD56"
let        kDefaultRecordNames = kRootName + kColonSeparator + kRootName + kColonSeparator + kFavoritesRootName
let       kCloudDriveIsEnabled = "cloud drive is enabled"
let       kCreateCombinedEssay = "create combined essay"
let       kProductionEmailSent = "production email sent"
let       kShowMySubscriptions = "show my subscriptions"
let      kSmallMapIsVisibleKey = "small map is visible"
let      kLastChosenCheatSheet = "last chosen cheat sheet"
let    kTemporaryFullTitleMode = "temporary full title mode"
let  kUnderstandsNeedForAccess = "understands need for access to apple id"

let              kDotSeparator = kPeriod
let            kColonSeparator = kColon
let            kCommaSeparator = kComma
let            kCrumbSeparator = "      "
let         kUncommonSeparator = ":1:2:"
let         kLevelOneSeparator = "  ((a))  "
let         kLevelTwoSeparator = " (a|a) "
let       kLevelThreeSeparator = " (f) "
let        kLevelFourSeparator = " (v) "
let   kArrayTransformSeparator = "] . ["

let            kEssayTitleFont = ZFont(name: "TimesNewRomanPS-BoldMT", size: kDefaultEssayTitleFontSize) ?? ZFont.systemFont(ofSize: kDefaultEssayTitleFontSize)
let          kDefaultEssayFont = ZFont(name: "Times-Roman",            size: kDefaultEssayTextFontSize)  ?? ZFont.systemFont(ofSize: kDefaultEssayTextFontSize)
let                  kHelpFont = ZFont.systemFont    (ofSize: ZFont.systemFontSize)
let                  kBoldFont = ZFont.boldSystemFont(ofSize: ZFont.systemFontSize)
let               kItalicsFont = ZFont.systemFont    (ofSize: ZFont.systemFontSize)      .withTraits(.italic)
let             kLargeHelpFont = ZFont.systemFont    (ofSize: ZFont.systemFontSize + 1.0)
let             kLargeBoldFont = ZFont.boldSystemFont(ofSize: ZFont.systemFontSize + 1.0)
let          kLargeItalicsFont = ZFont.systemFont    (ofSize: ZFont.systemFontSize + 1.0).withTraits(.italic)
let     kFirstTimeStartupLevel = ZStartupLevel.firstStartup.rawValue
let               kScratchZone = Zone.uniqueZoneNamed(kScratchRootName, recordName: kScratchRootName, databaseID: .mineID)
let                 kBlankLine = NSAttributedString(string:       kNewLine, attributes: [.font : kDefaultEssayFont])
let           kDoubleBlankLine = NSAttributedString(string: kDoubleNewLine, attributes: [.font : kDefaultEssayFont])
let             kNoteSeparator = kBlankLine
let    kLineEndingsAndTabArray = [kReturn, kNewLine, kControlReturn, kTab]
