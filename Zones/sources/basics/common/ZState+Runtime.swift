//
//  ZState+Runtime.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

var  gTextEditorHandlesArrows                       = false
var   gIsEditingStateChanging                       = false
var    gRefusesFirstResponder                       = false
var     gRefusesAlterOrdering                       = false
var      gAllowSavingWorkMode                       = false
var       gHasFinishedStartup                       = false
var       gIsExportingToAFile                       = false
var        gKeyboardIsVisible                       = false
var          gIsReadyToShowUI                       = false
var          gDeferringRedraw                       = false
var           gPushIsDisabled                       = false
var            gTextCapturing                       = false
var             gIgnoreEvents                       = false
var             gNeedsRecount                       = false
var             gCancelSearch                       = false
var               gLaunchedAt                       = Date()
var           gAnglesFraction                       = 42.0
var              gAnglesDelta                       = 15.0
var               gDebugCount                       = 0
var        gInterruptionCount                       = 0
var    gTimeUntilCurrentEvent :       TimeInterval  = 0  // by definition, first event is startup
var             gCurrentTrait :             ZTrait?
var     gCurrentMouseDownZone :               Zone?
var gCurrentMouseDownLocation :            CGFloat?
var       gCurrentBrowseLevel :                Int?
var        gCurrentKeyPressed :             String?

var                   gIsLate :               Bool  { return gBatches.isLate }
var                   gIsDark :               Bool  { return gDarkMode == .Dark }
var                   gIsMine :               Bool  { return gDatabaseID == .mineID }
var                gIsEditing :               Bool  { return gIsEditIdeaMode || gIsEssayMode }
var            gIsHelpVisible :               Bool  { return gHelpWindow?.isVisible ?? false }
var          gIsHelpFrontmost :               Bool  { return gHelpWindow?.isKeyWindow ?? false }
var         gGrabbedCanTravel :               Bool  { return gSelecting.currentMoveableMaybe?.isBookmark ?? false }
var       gBrowsingIsConfined :               Bool  { return gConfinementMode == .list }
var            gListsGrowDown :               Bool  { return gListGrowthMode  == .down }
var           gDuplicateEvent :               Bool  { return gCurrentEvent != nil && (gTimeSinceCurrentEvent < 0.4) }
var           gIsEditIdeaMode :               Bool  { return gWorkMode == .wEditIdeaMode }
var            gIsStartupMode :               Bool  { return gWorkMode == .wStartupMode }
var            gIsResultsMode :               Bool  { return gWorkMode == .wResultsMode }
var              gIsEssayMode :               Bool  { return gWorkMode == .wEssayMode }
var                gIsMapMode :               Bool  { return gWorkMode == .wMapMode }
var              gIsSearching :               Bool  { return gSearching.searchState != .sNot }
var           gIsNotSearching :               Bool  { return gSearching.searchState == .sNot }
var        gSearchStateIsList :               Bool  { return gSearching.searchState == .sList }
var       gSearchStateIsEntry :               Bool  { return gSearching.searchState == .sEntry }
var           gCanDrawWidgets :               Bool  { return gIsMapOrEditIdeaMode || !gSearchStateIsList }
var      gIsMapOrEditIdeaMode :               Bool  { return gIsMapMode || gIsEditIdeaMode }
var          gCanSaveWorkMode :               Bool  { return gIsMapMode || gIsEssayMode }
var          gIsDraggableMode :               Bool  { return gIsMapMode || gIsEditIdeaMode || gIsEssayMode }
var   gDrawCirclesAroundIdeas :               Bool  { return gCirclesDisplayMode.contains(.cIdeas) }
var      gDetailsViewIsHidden :               Bool  { return gMainController?.detailView?.isHidden ?? true }
var           gMapIsResponder :               Bool  { return gMainWindow?.firstResponder == gMapView && gMapView != nil }
var               gUserIsIdle :               Bool  { return gUserActiveInWindow == nil }
var         gCurrentEssayZone :               Zone? { return gCurrentEssay?.zone }
var         gUniqueRecordName :             String  { return CKRecordID().recordName }
var                   gUserID :             String? { return (gFileManager.ubiquityIdentityToken as? Data)?.base64EncodedString().fileSystemSafe }
var                  gRecords :           ZRecords  { return (kIsPhone && gShowFavoritesMapForIOS) ? gFavoritesCloud : gRemoteStorage.currentRecords }
var                 gDarkMode :     InterfaceStyle  { return InterfaceStyle() }
var            gModifierFlags :        ZEventFlags  { return ZEvent.modifierFlags } // use when don't have an event handy
var    gTimeSinceCurrentEvent :       TimeInterval  { return Date.timeIntervalSinceReferenceDate - gTimeUntilCurrentEvent }
var          gOtherDatabaseID :        ZDatabaseID  { return gDatabaseID == .mineID ? .everyoneID : .mineID }
var  gLightishBackgroundColor :             ZColor  { return gAccentColor.lightish(by: 1.02)  }
var          gDarkAccentColor :             ZColor  { return gAccentColor.darker  (by: 1.3) }
var       gLighterActiveColor :             ZColor  { return gActiveColor.lighter (by: 4.0)   }
var          gBackgroundColor :             ZColor  { return gIsDark ? kDarkestGrayColor : kWhiteColor }

func       gConcealmentString(hide: Bool) -> String { return (hide ? "hide" : "reveal") }
func        gToggleDatabaseID()                     { gDatabaseID  =  gOtherDatabaseID }
func         gSetEditIdeaMode()                     { gWorkMode    = .wEditIdeaMode }
func          gSetMapWorkMode()                     { gWorkMode    = .wMapMode }

func gInvokeUsingDatabaseID(_ databaseID: ZDatabaseID?, block: Closure) {
	if  databaseID != nil && databaseID != gDatabaseID {
		gRemoteStorage.detectWithMode(databaseID!) {
			block()

			return false
		}
	} else {
		block()
	}
}

func gToggleLayoutMode() {
	gMapLayoutMode = gMapLayoutMode.next

	gSignal([.sAll, .spRelayout, .spPreferences])
}

func gToggleShowToolTips() {
	gShowToolTips = !gShowToolTips

	gSignal([.sDetails])
	gRelayoutMaps()
}

func gToggleShowExplanations() {
	gShowExplanations = !gShowExplanations
	gShowMainControls = true

	gHideExplanation()
	gSignal([.sDetails])
}

var gCompleteHereRecordNames: StringsArray {
	var       references = gHereRecordNames.components(separatedBy: kColonSeparator)
	var          changed = false

	func rootFor(_ index: Int) -> Zone? {
		if  let     dbid = ZDatabaseIndex(rawValue: index)?.databaseID,
			let zRecords = gRemoteStorage.zRecords(for: dbid),
			let     root = zRecords.rootZone {

			return  root
		}

		return nil
	}

	while   references.count < 3 {
		let    index = references.count
		if  let root = rootFor(index),
			let name = root.recordName {
			changed  = true
			references.append(name)
		}
	}

	// detect and fix bad values
	// bad idea to do this before progeny are added

	if  gIsReadyToShowUI, references.count  > 2 {
		let          name = references[2]
		if  let      root = rootFor(2) {
			let rootNames = root.all.map { return $0.recordName ?? kEmpty }
			if !rootNames.contains(name) {
				references[2] = kFavoritesRootName    // reset to default
				changed       = true
			}
		}
	}

	if  changed {
		gHereRecordNames = references.joined(separator: kColonSeparator)
	}

	return references
}

var gCurrentEvent: ZEvent? {
	didSet {
		gTimeUntilCurrentEvent = Date.timeIntervalSinceReferenceDate
	}
}

var gHere: Zone {
	get {
		return gRecords.currentHere
	}

	set {
		gRecords.currentHere = newValue
		if  let           id = newValue.maybeDatabaseID {
			gDatabaseID      = id
		}

		newValue.assureZoneAdoption()
		gFavoritesCloud.push(newValue)

	}
}

var gHereMaybe: Zone? {
	get { return !gHasFinishedStartup ? nil : gRecords.hereZoneMaybe }
    set { gRecords.hereZoneMaybe = newValue }
}

var gUserActivityDetected: Bool {
	if  let w = gUserActiveInWindow {
		printDebug(.dUser, "throwing user interrupt in \(w.description) \(gInterruptionCount)")
		gInterruptionCount += 1

		return true
	}

	return false
}
