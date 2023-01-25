//
//  ZState.swift
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
var       gHasFinishedStartup                       = false
var       gIsExportingToAFile                       = false
var        gKeyboardIsVisible                       = false
var          gIsReadyToShowUI                       = false
var          gDeferringRedraw                       = false
var           gPushIsDisabled                       = false
var            gTextCapturing                       = false
var             gIgnoreEvents                       = false
var             gNeedsRecount                       = false
var               gLaunchedAt                       = Date()
var           gAnglesFraction                       = 42.0
var              gAnglesDelta                       = 15.0
var               gDebugCount                       = 0
var        gInterruptionCount                       = 0
var    gTimeUntilCurrentEvent :        TimeInterval = 0  // by definition, first event is startup
var         gCDMigrationState :   ZCDMigrationState = .firstTime
var             gCurrentTrait :             ZTrait?
var     gCurrentMouseDownZone :               Zone?
var gCurrentMouseDownLocation :            CGFloat?
var       gCurrentBrowseLevel :                Int?
var        gCurrentKeyPressed :             String?

var                   gIsDark :                Bool { return gDarkMode == .Dark }
var                   gIsLate :                Bool { return gBatches.isLate }
var                   gIsMine :                Bool { return gDatabaseID == .mineID }
var                gIsEditing :                Bool { return gIsEditIdeaMode || gIsEssayMode }
var          gIsHelpFrontmost :                Bool { return gHelpWindow?.isKeyWindow ?? false }
var         gGrabbedCanTravel :                Bool { return gSelecting.currentMoveableMaybe?.isBookmark ?? false }
var       gBrowsingIsConfined :                Bool { return gConfinementMode == .list }
var            gListsGrowDown :                Bool { return gListGrowthMode  == .down }
var           gDuplicateEvent :                Bool { return gCurrentEvent != nil && (gTimeSinceCurrentEvent < 0.4) }
var           gIsEditIdeaMode :                Bool { return gWorkMode == .wEditIdeaMode }
var            gIsStartupMode :                Bool { return gWorkMode == .wStartupMode }
var            gIsResultsMode :                Bool { return gWorkMode == .wResultsMode }
var              gIsEssayMode :                Bool { return gWorkMode == .wEssayMode }
var                gIsMapMode :                Bool { return gWorkMode == .wMapMode }
var              gIsSearching :                Bool { return gSearching.state != .sNot }
var           gIsNotSearching :                Bool { return gSearching.state == .sNot }
var     gSearchResultsVisible :                Bool { return gSearching.state == .sList }
var    gWaitingForSearchEntry :                Bool { return gSearching.state == .sEntry }
var           gCanDrawWidgets :                Bool { return gIsMapOrEditIdeaMode || !gSearchResultsVisible }
var      gIsMapOrEditIdeaMode :                Bool { return gIsMapMode || gIsEditIdeaMode }
var          gCanSaveWorkMode :                Bool { return gIsMapMode || gIsEssayMode }
var          gIsDraggableMode :                Bool { return gIsMapMode || gIsEditIdeaMode || gIsEssayMode }
var   gDrawCirclesAroundIdeas :                Bool { return gCirclesDisplayMode.contains(.cIdeas) }
var      gDetailsViewIsHidden :                Bool { return gMainController?.detailView?.isHidden ?? true }
var           gMapIsResponder :                Bool { return gMainWindow?.firstResponder == gMapView && gMapView != nil }
var             gUserIsExempt :                Bool { return gIgnoreExemption ? false  : gUser?.isExempt ?? false } // discard this?
var               gUserIsIdle :                Bool { return gUserActiveInWindow == nil }
var         gCurrentEssayZone :               Zone? { return gCurrentEssay?.zone }
var         gUniqueRecordName :              String { return CKRecordID().recordName }
var                  gRecords :            ZRecords { return (kIsPhone && gShowSmallMapForIOS) ? gFavorites : gRemoteStorage.currentRecords }
var                 gDarkMode :      InterfaceStyle { return InterfaceStyle() }
var            gModifierFlags :         ZEventFlags { return ZEvent.modifierFlags } // use when don't have an event handy
var    gTimeSinceCurrentEvent :        TimeInterval { return Date.timeIntervalSinceReferenceDate - gTimeUntilCurrentEvent }
var   gDeciSecondsSinceLaunch :                 Int { return Int(Date().timeIntervalSince(gLaunchedAt) * 10.0) }
var          gOtherDatabaseID :         ZDatabaseID { return gDatabaseID == .mineID ? .everyoneID : .mineID }
var  gLightishBackgroundColor :              ZColor { return gAccentColor.lightish(by: 1.02)  }
var          gDarkAccentColor :              ZColor { return gAccentColor.darker  (by: 1.3) }
var       gLighterActiveColor :              ZColor { return gActiveColor.lighter (by: 4.0)   }
var          gBackgroundColor :              ZColor { return  gIsDark ? kDarkestGrayColor : kWhiteColor }

func       gConcealmentString(hide: Bool) -> String { return (hide ? "hide" : "reveal") }
func        gToggleDatabaseID()                     { gDatabaseID  =  gOtherDatabaseID }
func         gSetEditIdeaMode()                     { gWorkMode    = .wEditIdeaMode }
func          gSetMapWorkMode()                     { gWorkMode    = .wMapMode }

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

fileprivate var gCollapsed : StringsArray?
fileprivate var gExpanded  : StringsArray?

enum ZIdeaVisibilityMode : Int {
	case mExpanded
	case mCollapsed

	var array : StringsArray {
		switch self {
		case .mExpanded:  return gExpandedIdeas
		case .mCollapsed: return gCollapsedIdeas
		}
	}

	func setArray(_ array: StringsArray) {
		switch self {
		case .mExpanded:  gExpandedIdeas  = array
		case .mCollapsed: gCollapsedIdeas = array
		}
	}
}

var gCollapsedIdeas : StringsArray {
	get {
		if  gCollapsed == nil {
			let  value  = getPreferencesString(for: kCollapsedIdeas, defaultString: kEmpty)
			gCollapsed  = value?.components(separatedBy: kColonSeparator)
		}
		
		return gCollapsed!
	}
	
	set {
		gCollapsed = newValue
		
		setPreferencesString(newValue.joined(separator: kColonSeparator), for: kCollapsedIdeas)
	}
}

var gExpandedIdeas : StringsArray {
    get {
        if  gExpanded == nil {
            let value  = getPreferencesString(for: kExpandedIdeas, defaultString: kEmpty)
            gExpanded  = value?.components(separatedBy: kColonSeparator)
        }

        return gExpanded!
    }

    set {
        gExpanded = newValue

        setPreferencesString(newValue.joined(separator: kColonSeparator), for: kExpandedIdeas)
    }
}

var gHere: Zone {
	get {
		return gRecords.currentHere
	}

	set {
		gDatabaseID          = newValue.databaseID
		gRecords.currentHere = newValue

		newValue.assureAdoption()
		gFavorites.push()
	}
}

var gHereMaybe: Zone? {
	get { return !gHasFinishedStartup ? nil : gRecords.hereZoneMaybe }
    set { gRecords.hereZoneMaybe = newValue }
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

var gUserActivityDetected: Bool {
	if  let w = gUserActiveInWindow {
		printDebug(.dUser, "throwing user interrupt in \(w.description) \(gInterruptionCount)")
		gInterruptionCount += 1

		return true
	}

	return false
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

var gColorfulMode : Bool {
	get { return getPreferencesBool(   for: kColorfulMode, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kColorfulMode) }
}

var gShowSmallMapForIOS : Bool {
	get { return getPreferencesBool(   for: kShowSmallMap, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kShowSmallMap) }
}

var gShowExplanations : Bool {
	get { return getPreferencesBool(   for: kShowExplanations, defaultBool: true) }
	set { setPreferencesBool(newValue, for: kShowExplanations) }
}

var gShowMainControls : Bool {
	get { return getPreferencesBool(   for: kShowMainControls, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kShowMainControls) }
}

var gCreateCombinedEssay : Bool {
	get { return getPreferencesBool(   for: kCreateCombinedEssay, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kCreateCombinedEssay) }
}

var gShowToolTips : Bool {
	get { return getPreferencesBool(   for: kShowToolTips, defaultBool: true) }
	set { setPreferencesBool(newValue, for: kShowToolTips) }
}

enum ZStartupLevel: Int {
	case firstStartup
	case localOkay
	case pleaseWait
	case pleaseEnableDrive
}

var gStartupLevel : ZStartupLevel {
	get { return  ZStartupLevel(rawValue: getPreferencesInt(for: kStartupLevel, defaultInt: kFirstTimeStartupLevel))! }
	set { setPreferencesInt(newValue.rawValue, for: kStartupLevel) }
}

var gStartupCount : Int {
	get { return getPreferencesInt(for: kStartupCount, defaultInt: 0) }
	set { setPreferencesInt(newValue, for: kStartupCount) }
}

var gEssayTitleMode : ZEssayTitleMode {
	get { return ZEssayTitleMode(rawValue: getPreferencesInt(for: kEssayTitleMode, defaultInt: ZEssayTitleMode.sFull.rawValue))! }
	set { setPreferencesInt(newValue.rawValue, for: kEssayTitleMode) }
}

var gHereRecordNames: String {
    get { return getPreferenceString(    for: kHereRecordNames) { return kDefaultRecordNames }! }
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

var gAccentColor: ZColor {
	get { return !gColorfulMode ? gIsDark ? kDarkerGrayColor : kLighterGrayColor : getPreferencesColor( for: kAccentColorKey, defaultColor: ZColor(red: 241.0/256.0, green: 227.0/256.0, blue: 206.0/256.0, alpha: 1.0)) }
	set { setPreferencesColor(newValue, for: kAccentColorKey) }
}

var gActiveColor: ZColor {
	get { return !gColorfulMode ? kGrayColor : getPreferencesColor( for: kActiveColorKey, defaultColor: ZColor.purple.darker(by: 1.5)) }
	set { setPreferencesColor(newValue, for: kActiveColorKey) }
}

struct ZFilterOption: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let fBookmarks = ZFilterOption(rawValue: 1 << 0)
	static let     fNotes = ZFilterOption(rawValue: 1 << 1)
	static let     fIdeas = ZFilterOption(rawValue: 1 << 2)
	static let      fNone = ZFilterOption([])
	static let       fAll = ZFilterOption(rawValue: 7)
}

var gFilterOption: ZFilterOption {
	get { return ZFilterOption(rawValue: getPreferencesInt(for: kFilterOption, defaultInt: ZFilterOption.fAll.rawValue)) }
	set { setPreferencesInt(newValue.rawValue, for: kFilterOption) }
}

struct ZSearchScopeOption: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let    fPublic = ZSearchScopeOption(rawValue: 1 << 0)
//	static let    fShared = ZSearchScopeOption(rawValue: 1 << 1)
	static let      fMine = ZSearchScopeOption(rawValue: 1 << 1)
	static let     fTrash = ZSearchScopeOption(rawValue: 1 << 2)
	static let fFavorites = ZSearchScopeOption(rawValue: 1 << 3)
	static let    fOrphan = ZSearchScopeOption(rawValue: 1 << 4)
	static let      fNone = ZSearchScopeOption([])
	static let       fAll = ZSearchScopeOption(rawValue: 0x11)
}

var gSearchScopeOption: ZSearchScopeOption {
	get { return ZSearchScopeOption(rawValue: getPreferencesInt(for: kSearchScopeOption, defaultInt: ZSearchScopeOption.fMine.rawValue)) }
	set { setPreferencesInt(newValue.rawValue, for: kSearchScopeOption) }
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

var gMapRotationAngle : CGFloat {
	get {
		let  angle = CGFloat.zero
		let string = getPreferenceString(for: kMapRotationAngle) { return angle.stringTo(precision: 2) }

		return string?.floatValue ?? angle
	}

	set {
		let string = newValue.description

		setPreferencesString(string, for: kMapRotationAngle)
	}
}

var gMapOffset: CGPoint {
	get {
		let  point = CGPoint.zero
		let string = getPreferenceString(for: kMapOffsetKey) { return NSStringFromPoint(point) }
		
		return string?.cgPoint ?? point
	}
	
	set {
		let string = NSStringFromPoint(newValue)
		
		setPreferencesString(string, for: kMapOffsetKey)
	}
}

enum ZConfinementMode: String {
	case list = "List"
	case all  = "All"

	var next: ZConfinementMode {
		switch self {
			case .list: return .all
			default:    return .list
		}
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

struct ZCirclesDisplayMode: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let cIdeas = ZCirclesDisplayMode(rawValue: 0x0001)
	static let cRings = ZCirclesDisplayMode(rawValue: 0x0002)

	static func createFrom(_ set: IndexSet) -> ZCirclesDisplayMode {
		var mode = ZCirclesDisplayMode()

		if  set.contains(0) {
			mode.insert(.cIdeas)
		}

		if  set.contains(1) {
			mode.insert(.cRings)
		}

		return mode
	}

	var indexSet: IndexSet {
		var set = IndexSet()

		if  contains(.cIdeas) {
			set.insert(0)
		}

		if  contains(.cRings) {
			set.insert(1)
		}

		return set
	}

}

var gCirclesDisplayMode: ZCirclesDisplayMode {
	get {
		let value = UserDefaults.standard.object(forKey: kCirclesDisplayMode) as? Int ?? 0

		return ZCirclesDisplayMode(rawValue: value)
	}
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey: kCirclesDisplayMode)
		UserDefaults.standard.synchronize()
	}
}

var gMapLayoutMode: ZMapLayoutMode {
	get {
		let value = UserDefaults.standard.object(forKey: kMapLayoutMode) as? Int
		var mode  = ZMapLayoutMode.linearMode

		if  let v = value {
			mode  = ZMapLayoutMode(rawValue: v)!
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
		
		if  value == nil {
			value  = 1.00
			
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

var gDefaultProgressTime: Double {
	get {
		var value: Double? = UserDefaults.standard.object(forKey: kProgressTimeKey) as? Double

		if  value == nil {
			value  = kDefaultProgressTime

			UserDefaults.standard.set(value, forKey:kProgressTimeKey)
			UserDefaults.standard.synchronize()
		}

		return value!
	}

	set {
		UserDefaults.standard.set(newValue, forKey:kProgressTimeKey)
		UserDefaults.standard.synchronize()
	}
}

var gLineThickness: CGFloat {
	get {
		var value: CGFloat? = UserDefaults.standard.object(forKey: kThickness) as? CGFloat
		
		if  value == nil {
			value  = kDefaultLineThickness
			
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

var gHorizontalGap: CGFloat {
	get {
		var value: CGFloat? = UserDefaults.standard.object(forKey: kHorizontalGap) as? CGFloat

		if  value == nil {
			value  = kDefaultHorizontalGap

			UserDefaults.standard.set(value, forKey:kHorizontalGap)
			UserDefaults.standard.synchronize()
		}

		return value!
	}

	set {
		UserDefaults.standard.set(newValue, forKey:kHorizontalGap)
		UserDefaults.standard.synchronize()
	}
}

var gBaseFontSize: CGFloat {
	get {
		var value: CGFloat? = UserDefaults.standard.object(forKey: kBaseFontSize) as? CGFloat

		if  value == nil {
			value  = kDefaultBaseFontSize

			UserDefaults.standard.set(value, forKey:kBaseFontSize)
			UserDefaults.standard.synchronize()
		}

		return value!
	}

	set {
		UserDefaults.standard.set(newValue, forKey:kBaseFontSize)
		UserDefaults.standard.synchronize()
	}
}

enum ZListGrowthMode: String {
	case down = "Down"
	case up   = "Up"

	var next: ZListGrowthMode {
		switch self {
			case .down: return .up
			default:    return .down
		}
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
			viewID     = .vFirstHidden
			
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

enum ZWorkMode: String {
	case wEditIdeaMode = "i"
	case wStartupMode  = "s"
	case wResultsMode  = "?"
	case wEssayMode    = "n"
	case wMapMode      = "g"
}

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

var gUserActiveInWindow: ZActiveWindowID? {
	if  gMainWindow?.userIsActive ?? false {
		return .main
	}

	if  gHelpWindow?.userIsActive ?? false {
		return .help
	}

	return nil
}

var gLastLocation = CGPoint.zero

func gThrowOnUserActivity() throws {
	if  Thread.isMainThread {
		if  gUserActivityDetected {
			throw(ZInterruptionError.userInterrupted)
		}
	} else {
		try gFOREGROUND.sync {
			if  gUserActivityDetected {
				throw(ZInterruptionError.userInterrupted)
			}
		}
	}
}

func gDetailsViewIsVisible(for id: ZDetailsViewID) -> Bool {
	return gShowDetailsView && (gDetailsController?.viewIsVisible(for: id) ?? false)
}

func gRefreshCurrentEssay() {
	if  let identifier = getPreferencesString(for: kCurrentEssay, defaultString: kTutorialRecordName),
		let      essay = gFavorites.object(for: identifier) as? ZNote {
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

func getPreferencesFloat(for key: String, defaultFloat: CGFloat = .zero) -> CGFloat {
	return getPreferenceString(for: key) { return "\(defaultFloat)" }?.floatValue ?? defaultFloat
}

func setPreferencesFloat(_ iFloat: CGFloat = .zero, for key: String) {
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
