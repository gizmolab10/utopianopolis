//
//  ZState.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

var  gTextEditorHandlesArrows                     = false
var   gIsEditingStateChanging                     = false
var    gRefusesFirstResponder                     = false
var      gCreateCombinedEssay 			   		  = false
var       gHasFinishedStartup                     = false
var       gIsExportingToAFile                     = false
var       gProgressTimesReady                     = false
var        gKeyboardIsVisible                     = false
var         gGotProgressTimes                     = false
var          gIsReadyToShowUI                     = false
var          gDeferringRedraw                     = false
var           gPushIsDisabled                     = false
var            gTextCapturing                     = false
var             gNeedsRecount                     = false
var               gLaunchedAt                     = Date()
var             gDraggedZones                     = ZoneArray()
var            gProgressTimes                     = [ZOperationID : Double]()
var           gAnglesFraction                     = 42.0
var              gAnglesDelta                     = 15.0
var        gInterruptionCount                     = 0
var    gTimeUntilCurrentEvent:       TimeInterval = 0  // by definition, first event is startup
var           gMigrationState:    ZMigrationState = .firstTime
var             gDragRelation:         ZRelation?
var             gCurrentTrait:            ZTrait?
var              gDropIndices: NSMutableIndexSet?
var               gDropWidget:        ZoneWidget?
var                gDropCrumb: ZBreadcrumbButton?
var                gDragPoint:           CGPoint?
var                 gDropLine:          ZoneLine?
var     gCurrentMouseDownZone:              Zone?
var gCurrentMouseDownLocation:           CGFloat?
var       gCurrentBrowseLevel:               Int?
var        gCurrentKeyPressed:            String?

var                   gIsDark:               Bool { return gDarkMode == .Dark }
var                   gIsLate:               Bool { return gBatches.isLate }
var                   gIsHere:               Bool { return gHere == gSelecting.currentMoveableMaybe }
var                   gIsMine:               Bool { return gDatabaseID == .mineID }
var                gIsEditing:               Bool { return gIsEditIdeaMode || gIsEssayMode }
var               gIsDragging:               Bool { return !gDraggedZones.isEmpty }
var          gIsHelpFrontmost:               Bool { return gHelpWindow?.isKeyWindow ?? false }
var         gGrabbedCanTravel:               Bool { return gSelecting.currentMoveableMaybe?.isBookmark ?? false }
var       gBrowsingIsConfined:               Bool { return gConfinementMode == .list }
var          gIsFavoritesMode:               Bool { return gSmallMapMode    == .favorites }
var           gIsRecentlyMode:               Bool { return gSmallMapMode    == .recent }
var            gListsGrowDown:               Bool { return gListGrowthMode  == .down }
var           gDuplicateEvent:               Bool { return gCurrentEvent != nil && (gTimeSinceCurrentEvent < 0.4) }
var                gIsMapMode:               Bool { return gWorkMode == .wMapMode }
var              gIsEssayMode:               Bool { return gWorkMode == .wEssayMode }
var             gIsSearchMode:               Bool { return gWorkMode == .wSearchMode }
var            gIsStartupMode:               Bool { return gWorkMode == .wStartupMode }
var           gIsEditIdeaMode:               Bool { return gWorkMode == .wEditIdeaMode }
var           gIsNotSearching:               Bool { return gSearching.state == .sNot }
var     gSearchResultsVisible:               Bool { return gSearching.state == .sList }
var    gWaitingForSearchEntry:               Bool { return gSearching.state == .sEntry }
var        gIsSearchEssayMode:               Bool { return gSearching.priorWorkMode == .wEssayMode }
var      gIsMapOrEditIdeaMode:               Bool { return gIsMapMode || gIsEditIdeaMode }
var          gCanSaveWorkMode:               Bool { return gIsMapMode || gIsEssayMode }
var          gIsDraggableMode:               Bool { return gIsMapMode || gIsEditIdeaMode || gIsEssayMode }
var      gDetailsViewIsHidden:               Bool { return gMainController?.detailView?.isHidden ?? true }
var           gMapIsResponder:               Bool { return gMainWindow?.firstResponder == gMapView && gMapView != nil }
var             gUserIsExempt:               Bool { return gIgnoreExemption ? false : gUser?.isExempt ?? false } // discard this?
var         gCurrentEssayZone:              Zone? { return gCurrentEssay?.zone }
var         gUniqueRecordName:             String { return CKRecordID().recordName }
var      gCurrentSmallMapName:             String { return gIsRecentlyMode ? "recent" : "favorite" }
var   gCurrentSmallMapRecords:  ZSmallMapRecords? { return gIsRecentlyMode ? gRecents : gFavorites }
var                  gRecords:          ZRecords? { return (kIsPhone && gShowSmallMapForIOS) ? gCurrentSmallMapRecords : gRemoteStorage.currentRecords }
var                 gDarkMode:     InterfaceStyle { return InterfaceStyle() }
var            gModifierFlags:        ZEventFlags { return ZEvent.modifierFlags } // use when don't have an event handy
var    gTimeSinceCurrentEvent:       TimeInterval { return Date.timeIntervalSinceReferenceDate - gTimeUntilCurrentEvent }
var   gDeciSecondsSinceLaunch:                Int { return Int(Date().timeIntervalSince(gLaunchedAt) * 10.0) }
var          gOtherDatabaseID:        ZDatabaseID { return gDatabaseID == .mineID ? .everyoneID : .mineID }
var  gLightishBackgroundColor:             ZColor { return gAccentColor.lightish(by: 1.02)  }
var          gDarkAccentColor:             ZColor { return gAccentColor.darker  (by: 1.3) }
var       gLighterActiveColor:             ZColor { return gActiveColor.lighter (by: 4.0)   }
var         gDefaultTextColor:             ZColor { return (gIsDark && !gIsPrinting) ? kLighterGrayColor : kBlackColor }
var          gBackgroundColor:             ZColor { return  gIsDark ? kDarkestGrayColor : kWhiteColor }
var                gSmallFont:              ZFont { return .systemFont(ofSize: gSmallFontSize) }
var                gMicroFont:              ZFont { return .systemFont(ofSize: gSmallFontSize * kSmallMapReduction * kSmallMapReduction) }
var                 gTinyFont:              ZFont { return .systemFont(ofSize: gSmallFontSize * kSmallMapReduction) }
var                  gBigFont:              ZFont { return .systemFont(ofSize: gBigFontSize) }

func        gToggleDatabaseID()                   { gDatabaseID   =  gOtherDatabaseID }
func         gSetEditIdeaMode()                   { gWorkMode     = .wEditIdeaMode }
func           gSetBigMapMode()                   { gWorkMode     = .wMapMode }

func gToggleLayoutMode() {
	gMapLayoutMode = gMapLayoutMode.next

	gRelayoutMaps()
}

func gToggleShowTooltips() {
	gShowToolTips = !gShowToolTips

	gSignal([.sDetails])
	gRelayoutMaps()
}

func gToggleSmallMapMode(_ OPTION: Bool = false, forceToggle: Bool = false) {
	if  let c = gDetailsController {
		func toggle() {
			gSmallMapMode = gIsRecentlyMode ? .favorites : .recent

			if  OPTION {			        // if any grabs are in current small map, move them to other map
				let currentID : ZDatabaseID = gIsRecentlyMode ? .recentsID   : .favoritesID
				let   priorID : ZDatabaseID = gIsRecentlyMode ? .favoritesID : .recentsID

				gSelecting.swapGrabsFrom(priorID, toID: currentID)
			}
		}

		if !c.viewIsVisible(for: .vSmallMap) {
			c.showViewFor       (.vSmallMap)

			if  forceToggle {
				toggle()
			}
		} else {
			toggle()
		}

		gShowDetailsView = true    	// make sure the details view is visible

		gSignal([.spMain, .sDetails, .spSmallMap, .spRelayout])
	}
}

func gLoadProgressTimes() {
	if  let string = getPreferenceString(for: kProgressTimes) {
		let  pairs = string.components(separatedBy: kCommaSeparator)

		for pair in pairs {
			let       items = pair.components(separatedBy: kColonSeparator)
			if  items.count > 1,
				let      op = items[0].integerValue,
				let    time = items[1].doubleValue {

				gSetProgressTime(opInt: op, value: time)
			}
		}
	}
}

func gStoreProgressTimes() {
	var separator = kEmpty
	var  storable = kEmpty

	for (op, value) in gProgressTimes {
		if  value >= 1.5 {
			storable.append("\(separator)\(op)\(kColonSeparator)\(value)")

			separator = kCommaSeparator
		}
	}

	setPreferencesString(storable, for: kProgressTimes)
}

var gTotalTime : Double {
	if  gAssureProgressTimesAreLoaded() {
		return gProgressTimes.values.reduce(0, +)
	}

	return 0.0
}

func gSetProgressTime(opInt: Int, value: Double?) {
	if  let op = ZOperationID(rawValue: opInt) {
		let time = value ?? Double(op.progressTime)

		if  time > 1 {
			gProgressTimes[op] = time
		}
	}
}


func gAssureProgressTimesAreLoaded() -> Bool {
	if  gProgressTimesReady, !gGotProgressTimes {
		for op in ZOperationID.oStartingUp.rawValue ... ZOperationID.oDone.rawValue {
			gSetProgressTime(opInt: op, value: nil)
		}

		gLoadProgressTimes()

		gGotProgressTimes = true
	}

	return gGotProgressTimes
}

var gTimePerRecord : Int {
	switch gMigrationState {         // TODO: adjust for cpu speed
		case .normal: return 800
		default:      return 130
	}
}

var gCurrentEvent: ZEvent? {
	didSet {
		gTimeUntilCurrentEvent = Date.timeIntervalSinceReferenceDate
	}
}

var gDebugModes : ZDebugMode {
	get { return ZDebugMode(         rawValue: getPreferencesInt(for: kDebugModes, defaultInt: 0)) }
	set { setPreferencesInt(newValue.rawValue,                   for: kDebugModes) }
}

var gPrintModes : ZPrintMode {
	get { return ZPrintMode(         rawValue: getPreferencesInt(for: kPrintModes, defaultInt: 0)) }
	set { setPreferencesInt(newValue.rawValue,                   for: kPrintModes) }
}

var gCoreDataMode : ZCoreDataMode {
	get { return ZCoreDataMode(      rawValue: getPreferencesInt(for: kCoreDataMode, defaultInt: 0)) }
	set { setPreferencesInt(newValue.rawValue,                   for: kCoreDataMode) }
}

fileprivate var gHidden: StringsArray?

var gHiddenZones : StringsArray {
	get {
		if  gHidden == nil {
			let  value = getPreferencesString(for: kHiddenZones, defaultString: kEmpty)
			gHidden  = value?.components(separatedBy: kColonSeparator)
		}
		
		return gHidden!
	}
	
	set {
		gHidden = newValue
		
		setPreferencesString(newValue.joined(separator: kColonSeparator), for: kHiddenZones)
	}
}

fileprivate var gExpanded: StringsArray?

var gExpandedZones : StringsArray {
    get {
        if  gExpanded == nil {
            let  value = getPreferencesString(for: kExpandedZones, defaultString: kEmpty)
            gExpanded  = value?.components(separatedBy: kColonSeparator)
        }

        return gExpanded!
    }

    set {
        gExpanded = newValue

        setPreferencesString(newValue.joined(separator: kColonSeparator), for: kExpandedZones)
    }
}

var gHere: Zone {
	get {
		return gRecords!.currentHere
	}

	set {
		gDatabaseID           = newValue.databaseID
		gRecords?.currentHere = newValue

		newValue.assureAdoption()
		gRecents.push()

		if  gIsFavoritesMode {
			gFavorites.push()
		}
	}
}

var gHereMaybe: Zone? {
	get { return !gHasFinishedStartup ? nil : gRecords?.hereZoneMaybe }
    set { gRecords?.hereZoneMaybe = newValue }
}

var gCurrentHelpMode: ZHelpMode {
	get {
		if  let v = getPreferenceString(for: kLastChosenCheatSheet) {
			return ZHelpMode(rawValue: v) ?? .noMode
		}

		return .noMode
	}

	set {
		setPreferencesString(newValue.rawValue, for: kLastChosenCheatSheet)
	}
}

var gTemporaryFullTitleMode : Bool {
	get { return getPreferencesBool(   for: kTemporaryFullTitleMode, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kTemporaryFullTitleMode) }
}

var gShowMySubscriptions : Bool {
	get { return getPreferencesBool(   for: kShowMySubscriptions, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kShowMySubscriptions) }
}

var gNeedsMigrate : Bool {
	get { return getPreferencesBool(   for: kNeedsMigrationKey, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kNeedsMigrationKey) }
}

var gShowDetailsView : Bool {
	get { return getPreferencesBool(   for: kShowDetails, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kShowDetails) }
}

var gClipBreadcrumbs : Bool {
	get { return getPreferencesBool(   for: kClipBreadcrumbs, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kClipBreadcrumbs) }
}

var gStartupLevel : ZStartupLevel {
	get { return  ZStartupLevel(rawValue: getPreferencesInt(for: kStartupLevel, defaultInt: kFirstTimeStartupLevel))! }
	set { setPreferencesInt(newValue.rawValue, for: kStartupLevel) }
}

var gEssayTitleMode : ZEssayTitleMode {
	get { return ZEssayTitleMode(rawValue: getPreferencesInt(for: kEssayTitleMode, defaultInt: ZEssayTitleMode.sFull.rawValue))! }
	set { setPreferencesInt(newValue.rawValue, for: kEssayTitleMode) }
}

var gColorfulMode : Bool {
	get { return getPreferencesBool(   for: kColorfulMode, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kColorfulMode) }
}

var gShowSmallMapForIOS : Bool {
	get { return getPreferencesBool(   for: kShowSmallMap, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kShowSmallMap) }
}

var gHereRecordNames: String {
    get { return getPreferenceString(    for: kHereRecordNames) { return kTutorialRecordName + kColonSeparator + kRootName }! }
    set { setPreferencesString(newValue, for: kHereRecordNames) }
}

var gAuthorID: String? {    // persist for file read on launch
    get { return getPreferenceString(    for: kAuthorID) { return nil } }
    set { setPreferencesString(newValue, for: kAuthorID) }
}

var gUserRecordName: String? {    // persist for file read on launch
    get { return getPreferenceString(    for: kUserRecordName) }
    set { setPreferencesString(newValue, for: kUserRecordName) }
}

var gSmallMapIsVisible: Bool {
	get { return getPreferencesBool(   for: kSmallMapIsVisibleKey, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kSmallMapIsVisibleKey) }
}

var gAccentColor: ZColor {
	get { return !gColorfulMode ? gIsDark ? kDarkerGrayColor : kLighterGrayColor : getPreferencesColor( for: kAccentColorKey, defaultColor: ZColor(red: 241.0/256.0, green: 227.0/256.0, blue: 206.0/256.0, alpha: 1.0)) }
	set { setPreferencesColor(newValue, for: kAccentColorKey) }
}

var gActiveColor: ZColor {
	get { return !gColorfulMode ? kGrayColor : getPreferencesColor( for: kActiveColorKey, defaultColor: ZColor.purple.darker(by: 1.5)) }
	set { setPreferencesColor(newValue, for: kActiveColorKey) }
}

var gFilterOption: ZFilterOption {
	get { return ZFilterOption(rawValue: getPreferencesInt(for: kFilterOption, defaultInt: ZFilterOption.fAll.rawValue)) }
	set { setPreferencesInt(newValue.rawValue, for: kFilterOption) }
}

var gWindowRect: CGRect {
	get { return getPreferencesRect(for: kWindowRectKey, defaultRect: kDefaultWindowRect) }
	set { setPreferencesRect(newValue, for: kWindowRectKey) }
}

var gEmailTypesSent: String {
    get {
        let pref = getPreferenceString(for: kEmailTypesSent) ?? kEmpty
        let sent = gUser?.sentEmailType ?? pref
        
        setPreferencesString(sent, for: kEmailTypesSent)
        gUser?.sentEmailType = sent
        
        return sent
    }
    
    set {
        setPreferencesString(newValue, for: kEmailTypesSent)
        gUser?.sentEmailType = newValue
    }
}

var gGenericOffset: CGSize {
	get {
		var offset = getPreferencesSize(for: kGenericOffsetKey, defaultSize: CGSize(width: 30.0, height: 2.0))
		
		if  kIsPhone {
			offset.height += 5.0
		}
		
		return offset
	}

	set {
		setPreferencesSize(newValue, for: kGenericOffsetKey)
	}
}

var gScrollOffset: CGPoint {
	get {
		let  point = CGPoint.zero
		let string = getPreferenceString(for: kScrollOffsetKey) { return NSStringFromPoint(point) }
		
		return string?.cgPoint ?? point
	}
	
	set {
		let string = NSStringFromPoint(newValue)
		
		setPreferencesString(string, for: kScrollOffsetKey)
	}
}

var gConfinementMode: ZConfinementMode {
	get {
		let value  = UserDefaults.standard.object(forKey: kConfinementMode) as? String
		var mode   = ZConfinementMode.list

		if  value != nil {
			mode   = ZConfinementMode(rawValue: value!)!
		} else {
			UserDefaults.standard.set(mode.rawValue, forKey:kConfinementMode)
			UserDefaults.standard.synchronize()
		}

		return mode
	}

	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kConfinementMode)
		UserDefaults.standard.synchronize()
	}
}

var gSmallMapMode: ZSmallMapMode {
	get {
		var mode   = ZSmallMapMode.favorites // default is favorites
		let value  = UserDefaults.standard.object(forKey: kSmallMapMode) as? String

		if  let  v = value,
			let  m = ZSmallMapMode(rawValue: v) {
			mode   = m
		} else {
			UserDefaults.standard.set(mode.rawValue, forKey:kSmallMapMode)
			UserDefaults.standard.synchronize()
		}

		return mode
	}

	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kSmallMapMode)
		UserDefaults.standard.synchronize()
	}
}

var gShowToolTips : Bool {
	get {
		var value  = UserDefaults.standard.object(forKey: kShowToolTips) as? Bool

		if  value == nil {
			value  = true

			UserDefaults.standard.set(true, forKey:kShowToolTips)
			UserDefaults.standard.synchronize()
		}

		return value!
	}

	set {
		UserDefaults.standard.set(newValue, forKey:kShowToolTips)
		UserDefaults.standard.synchronize()
	}

}

var gCountsMode: ZCountsMode {
	get {
		let value  = UserDefaults.standard.object(forKey: kCountsMode) as? Int
		var mode   = ZCountsMode.dots
		
		if  value != nil {
			mode   = ZCountsMode(rawValue: value!)!
		} else {
			UserDefaults.standard.set(mode.rawValue, forKey:kCountsMode)
			UserDefaults.standard.synchronize()
		}
		
		return mode
	}
	
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kCountsMode)
		UserDefaults.standard.synchronize()
	}
}

var gMapLayoutMode: ZMapLayoutMode {
	get {
		let value  = UserDefaults.standard.object(forKey: kMapLayoutMode) as? Int
		var mode   = ZMapLayoutMode.linearMode

		if  let  v = value {
			mode   = ZMapLayoutMode(rawValue: v)!
		} else {
			UserDefaults.standard.set(mode.rawValue, forKey:kMapLayoutMode)
			UserDefaults.standard.synchronize()
		}

		return mode
	}

	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kMapLayoutMode)
		UserDefaults.standard.synchronize()
	}
}

var gScaling: Double {
	get {
		var value: Double? = UserDefaults.standard.object(forKey: kScaling) as? Double
		
		if value == nil {
			value = 1.00
			
			UserDefaults.standard.set(value, forKey:kScaling)
			UserDefaults.standard.synchronize()
		}
		
		return value!
	}
	
	set {
		UserDefaults.standard.set(newValue, forKey:kScaling)
		UserDefaults.standard.synchronize()
	}
}

var gLineThickness: Double {
	get {
		var value: Double? = UserDefaults.standard.object(forKey: kThickness) as? Double
		
		if  value == nil {
			value = 1.25
			
			UserDefaults.standard.set(value, forKey:kThickness)
			UserDefaults.standard.synchronize()
		}
		
		return value!
	}
	
	set {
		UserDefaults.standard.set(newValue, forKey:kThickness)
		UserDefaults.standard.synchronize()
	}
}

var gListGrowthMode: ZListGrowthMode {
	get {
		var mode: ZListGrowthMode?
		
		if let object = UserDefaults.standard.object(forKey:kListGrowthMode) {
			mode      = ZListGrowthMode(rawValue: object as! String)
		}
		
		if  mode == nil {
			mode      = .down
			
			UserDefaults.standard.set(mode!.rawValue, forKey:kListGrowthMode)
			UserDefaults.standard.synchronize()
		}
		
		return mode!
	}
	
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kListGrowthMode)
		UserDefaults.standard.synchronize()
	}
}

var gDatabaseID: ZDatabaseID {
	get {
		var dbID: ZDatabaseID?
		
		if let object = UserDefaults.standard.object(forKey:kDatabaseID) {
			dbID      = ZDatabaseID(rawValue: object as! String)
		}
		
		if  dbID     == nil {
			dbID      = .everyoneID
			
			UserDefaults.standard.set(dbID!.rawValue, forKey:kDatabaseID)
			UserDefaults.standard.synchronize()
		}
		
		return dbID!
	}
	
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kDatabaseID)
		UserDefaults.standard.synchronize()
	}
}

var gHiddenDetailViewIDs: ZDetailsViewID {
	get {
		var viewID: ZDetailsViewID?
		
		if  let object = UserDefaults.standard.object(forKey:kDetailsState) {
			viewID     = ZDetailsViewID(rawValue: object as! Int)
		}
		
		if  viewID    == nil {
			viewID     = .vSimpleTools
			
			UserDefaults.standard.set(viewID!.rawValue, forKey:kDetailsState)
			UserDefaults.standard.synchronize()
		}
		
		return viewID!
	}
	
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kDetailsState)
		UserDefaults.standard.synchronize()
	}
}

#if os(iOS)
var gCurrentFunction : ZFunction {
	get {
		var function: ZFunction?
		
		if  let object = UserDefaults.standard.object(forKey:kActionFunction) {
			function   = ZFunction(rawValue: object as! String)
		}
		
		if  function  == nil {
			function   = .eTop
			
			UserDefaults.standard.set(function!.rawValue, forKey:kActionFunction)
			UserDefaults.standard.synchronize()
		}
		
		return function!
	}
	
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kActionFunction)
		UserDefaults.standard.synchronize()
	}
}

var gCurrentMapFunction : ZFunction {
	get {
		var function: ZFunction?
		
		if  let object = UserDefaults.standard.object(forKey:kCurrentMap) {
			function   = ZFunction(rawValue: object as! String)
		}
		
		if  function  == nil {
			function   = .eMe
			
			UserDefaults.standard.set(function!.rawValue, forKey:kActionFunction)
			UserDefaults.standard.synchronize()
		}
		
		return function!
	}

	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kCurrentMap)
		UserDefaults.standard.synchronize()
	}
}

#endif

var gWorkMode: ZWorkMode = .wStartupMode {
	didSet {
		if  gCanSaveWorkMode {
			setPreferencesString(gWorkMode.rawValue, for: kWorkMode)
		}
	}
}

var gCurrentEssay: ZNote? {
	didSet {
		setPreferencesString(gCurrentEssay?.identifier() ?? kEmpty, for: kCurrentEssay)

		if  gHasFinishedStartup, // avoid creating confused recents view
			gIsRecentlyMode {
		}
	}
}

var gAdjustedEssayTitleMode: ZEssayTitleMode {
	let isNote = (gCurrentEssay?.children.count ?? 0) == 0
	var   mode = gEssayTitleMode

	if !isNote {
		if  gTemporaryFullTitleMode {
			gTemporaryFullTitleMode =  false
			mode                    = .sFull
		}
	} else if gEssayTitleMode      == .sFull {
		gTemporaryFullTitleMode     =  true
		mode                        = .sTitle
	}

	return mode
}

// MARK: - actions
// MARK: -

enum ZActiveWindowID : Int {
	case main
	case help

	var description: String {
		switch self {
			case .main: return "m  "
			default:    return "  h"
		}
	}

}

var gUserIsActive: ZActiveWindowID? {
	if  gMainWindow?.userIsActive ?? false {
		return .main
	}

	if  gHelpWindow?.userIsActive ?? false {
		return .help
	}

	return nil
}

var gTestForUserActivity: Bool {
	if  let w = gUserIsActive {
		printDebug(.dUser, "throwing user interrupt in \(w.description) \(gInterruptionCount)")
		gInterruptionCount += 1

		return true
	}

	return false
}

var gLastLocation = CGPoint.zero

func gThrowOnUserActivity() throws {
	if  Thread.isMainThread {
		if  gTestForUserActivity {
			throw(ZInterruptionError.userInterrupted)
		}
	} else {
		gFOREGROUND.async {
			if  gTestForUserActivity {
				// cannot throw, so now what?
			}
		}
	}
}

func gDetailsViewIsVisible(for id: ZDetailsViewID) -> Bool {
	return gShowDetailsView && gDetailsController?.viewIsVisible(for: id) ?? false
}

func gRefreshCurrentEssay() {
	if  let identifier = getPreferencesString(for: kCurrentEssay, defaultString: kTutorialRecordName),
		let      essay = gRecents.object(for: identifier) as? ZNote {
		gCurrentEssay  = essay
	}
}

func gRefreshPersistentWorkMode() {
	if  let     mode = getPreferencesString(for: kWorkMode, defaultString: ZWorkMode.wEssayMode.rawValue),
		let workMode = ZWorkMode(rawValue: mode) {
		gWorkMode    = workMode
	}
}

@discardableResult func toggleGrowthAndConfinementModes(changesDirection: Bool) -> Bool {
	if  changesDirection {
		gListGrowthMode  = gListsGrowDown      ? .up  : .down
	} else {
		gConfinementMode = gBrowsingIsConfined ? .all : .list
	}

	return true
}

func emailSent(for type: ZSentEmailType) -> Bool {
	let types = gEmailTypesSent
    return types.contains(type.rawValue)
}

func recordEmailSent(for type: ZSentEmailType) {
    if  !emailSent  (for: type) {
        gEmailTypesSent.append(type.rawValue)
    }
}

// MARK: - internals
// MARK: -

func getPreferencesFloat(for key: String, defaultFloat: CGFloat = 0.0) -> CGFloat {
	return getPreferenceString(for: key) { return "\(defaultFloat)" }?.floatValue ?? defaultFloat
}

func setPreferencesFloat(_ iFloat: CGFloat = 0.0, for key: String) {
	setPreferencesString("\(iFloat)", for: key)
}

func getPreferencesSize(for key: String, defaultSize: CGSize = .zero) -> CGSize {
    return getPreferenceString(for: key) { return NSStringFromSize(defaultSize) }?.cgSize ?? defaultSize
}

func setPreferencesSize(_ iSize: CGSize = .zero, for key: String) {
    setPreferencesString(NSStringFromSize(iSize), for: key)
}

func getPreferencesRect(for key: String, defaultRect: CGRect = .zero) -> CGRect {
    return getPreferenceString(for: key) { return NSStringFromRect(defaultRect) }?.cgRect ?? defaultRect
}

func setPreferencesRect(_ iRect: CGRect = .zero, for key: String) {
    setPreferencesString(NSStringFromRect(iRect), for: key)
}

func getPreferencesColor(for key: String, defaultColor: ZColor) -> ZColor {
    var color = defaultColor

	do {
		if  let data = UserDefaults.standard.object(forKey: key) as? Data,
			let    c = try NSKeyedUnarchiver.unarchivedObject(ofClass: ZColor.self, from: data) {
			color    = c
		} else {
			setPreferencesColor(color, for: key)
		}
	} catch {
		setPreferencesColor(color, for: key)
	}

    return color.accountingForDarkMode
}

func setPreferencesColor(_ color: ZColor, for key: String) {
	do {
		let data: Data = try NSKeyedArchiver.archivedData(withRootObject: color.accountingForDarkMode, requiringSecureCoding: false)

		UserDefaults.standard.set(data, forKey: key)
		UserDefaults.standard.synchronize()
	} catch {

	}
}

func getPreferenceString(for key: String, needDefault: ToStringClosure? = nil) -> String? {
    if  let    string = UserDefaults.standard.object(forKey: key) as? String {
        return string
    }

    let defaultString = needDefault?()
    if  let    string = defaultString {
        setPreferencesString(string, for: key)
    }

    return defaultString
}

func getPreferencesString(for key: String, defaultString: String?) -> String? {
    return getPreferenceString(for: key) { return defaultString }
}

func setPreferencesString(_ iString: String?, for key: String) {
    if let string = iString {
        UserDefaults.standard.set(string, forKey: key)
        UserDefaults.standard.synchronize()
    }
}

func getPreferencesInt(for key: String, defaultInt: Int = 0) -> Int {
	return getPreferenceString(for: key) { return "\(defaultInt)" }?.integerValue ?? defaultInt
}

func setPreferencesInt(_ iInt: Int?, for key: String) {
	let value: String? = iInt == nil ? nil : "\(iInt!)"

	UserDefaults.standard.set(value, forKey: key)
	UserDefaults.standard.synchronize()
}

func getPreferencesBool(for key: String, defaultBool: Bool) -> Bool {
    if  let value: NSNumber = UserDefaults.standard.object(forKey: key) as? NSNumber {
        return value.boolValue
    }

    setPreferencesBool(defaultBool, for: key)

    return defaultBool
}

func setPreferencesBool(_ iBool: Bool, for key: String) {
    UserDefaults.standard.set(iBool, forKey: key)
    UserDefaults.standard.synchronize()
}
