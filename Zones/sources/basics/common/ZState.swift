//
//  ZState.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
let gFontDelta = 15.0
let gDotFactor = CGFloat(2.5)
var gTextOffset: CGFloat?
#elseif os(iOS)
import UIKit
let gFontDelta = 17.0
let gDotFactor = CGFloat(1.25)
var gTextOffset: CGFloat? { return gTextEditor.currentOffset }
#endif

var               gLaunchedAt                     = Date()
var              gDeferringRedraw                     = false
var            gTextCapturing                     = false
var          gIsReadyToShowUI                     = false
var        gKeyboardIsVisible                     = false
var        gArrowsDoNotBrowse                     = false
var       gHasFinishedStartup                     = false
var      gCreateCombinedEssay 			   		  = false
var    gRefusesFirstResponder                     = false
var   gIsEditingStateChanging                     = false
var        gInterruptionCount                     = 0
var    gTimeUntilCurrentEvent:       TimeInterval = 0  // by definition, first event is startup
var gCurrentMouseDownLocation:           CGFloat?
var     gCurrentMouseDownZone:              Zone?
var       gCurrentBrowseLevel:               Int?
var        gCurrentKeyPressed:            String?
var          gDragDropIndices: NSMutableIndexSet?
var             gDragRelation:         ZRelation?
var             gCurrentTrait:            ZTrait?
var             gDragDropZone:              Zone?
var              gDraggedZone:              Zone?
var                gDragPoint:           CGPoint?
var                 gExpanded:          [String]?

var                   gIsDark:               Bool { return gDarkMode == .Dark }
var                   gIsLate:               Bool { return gBatches.isLate }
var               gIsDragging:               Bool { return gDraggedZone != nil }
var          gIsHelpFrontmost:               Bool { return gHelpWindow?.isKeyWindow ?? false }
var       gBrowsingIsConfined:               Bool { return gConfinementMode   == .list }
var           gIsRecentlyMode:               Bool { return gFavoritesMode  == .recent }
var            gListsGrowDown:               Bool { return gListGrowthMode == .down }
var           gDuplicateEvent:               Bool { return gCurrentEvent != nil && (gTimeSinceCurrentEvent < 0.4) }
var               gIsNoteMode:               Bool { return gWorkMode == .noteMode }
var              gIsGraphMode:               Bool { return gWorkMode == .graphMode }
var             gIsSearchMode:               Bool { return gWorkMode == .searchMode }
var            gIsStartupMode:               Bool { return gWorkMode == .startupMode }
var           gIsEditIdeaMode:               Bool { return gWorkMode == .editIdeaMode }
var          gCanSaveWorkMode:               Bool { return gIsGraphMode || gIsNoteMode || gIsStartupMode }
var    gIsGraphOrEditIdeaMode:               Bool { return gIsGraphMode || gIsEditIdeaMode }
var            gProSkillLevel:               Bool { return gSkillLevel == .pro }
var       gExplorerSkillLevel:               Bool { return gSkillLevel == .explorer }
var    gTrailblazerSkillLevel:               Bool { return gSkillLevel == .trailblazer }
var         gCurrentEssayZone:              Zone? { return gCurrentEssay?.zone }
var                  gRecords:          ZRecords? { return gShowFavorites ? gFavorites : gCloud }
var                 gDarkMode:     InterfaceStyle { return InterfaceStyle() }
var	 			   gBlankLine: NSAttributedString { return NSMutableAttributedString(string: "\n", attributes: [.font : gEssayTitleFont]) }
var    gTimeSinceCurrentEvent:       TimeInterval { return Date.timeIntervalSinceReferenceDate - gTimeUntilCurrentEvent }
var                 gFontSize:            CGFloat { return gGenericOffset.height + CGFloat(gFontDelta) } // height 2 .. 20
var                 gDotWidth:             Double { return gDotHeight * 0.75 }
var                gDotHeight:             Double { return Double(gGenericOffset.height / gDotFactor) + 13.0 }
var       gChildrenViewOffset:             Double { return gDotWidth + Double(gGenericOffset.height) * 1.2 }
var   gDeciSecondsSinceLaunch:                Int { return Int(Date().timeIntervalSince(gLaunchedAt) * 10.0) }
var         gDefaultTextColor:             ZColor { return (gIsDark && !gIsPrinting) ? kLightestGrayColor : kBlackColor }
var          gBackgroundColor:             ZColor { return gIsDark ? kDarkestGrayColor : kWhiteColor }
var       gLighterActiveColor:             ZColor { return gActiveColor.lighter (by: 4.0)   }
var   gDarkishBackgroundColor:             ZColor { return gAccentColor.darkish (by: 1.028) }
var  gLightishBackgroundColor:             ZColor { return gAccentColor.lightish(by: 1.02)  }
var         gDefaultEssayFont:              ZFont { return ZFont(name: "Times-Roman",            size: gEssayTextFontSize)  ?? ZFont.systemFont(ofSize: gEssayTextFontSize) }
var           gEssayTitleFont:              ZFont { return ZFont(name: "TimesNewRomanPS-BoldMT", size: gEssayTitleFontSize) ?? ZFont.systemFont(ofSize: gEssayTitleFontSize) }
var            gFavoritesFont:              ZFont { return .systemFont(ofSize: gFontSize * kFavoritesReduction) }
var               gWidgetFont:              ZFont { return .systemFont(ofSize: gFontSize) }

let                 kBoldFont                     = ZFont.boldSystemFont(ofSize: ZFont.systemFontSize)
let    kFirstTimeStartupLevel                     = ZStartupLevel.firstTime.rawValue
let       kBeginnerSkillLevel                     = ZSkillLevel.explorer.rawValue
let       gEssayTitleFontSize                     = kDefaultEssayTitleFontSize
let        gEssayTextFontSize                     = kDefaultEssayTextFontSize

func         gSetEditIdeaMode()                   { gWorkMode = .editIdeaMode }
func            gSetGraphMode()                   { gWorkMode = .graphMode }

var gCurrentEvent: ZEvent? {
	didSet {
		gTimeUntilCurrentEvent = Date.timeIntervalSinceReferenceDate
	}
}

var gExpandedZones : [String] {
    get {
        if  gExpanded == nil {
            let  value = getPreferencesString(for: kExpandedZones, defaultString: "")
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
		return gRecords!.hereZone
	}

	set {
		if  let    dbID = newValue.databaseID {
			gDatabaseID = dbID
		}

		gRecords?.hereZone = newValue

		newValue.assureAdoption()
		gRecents.push()
	}
}

var gHereMaybe: Zone? {
    get { return gRecords?.hereZoneMaybe }
    set { gRecords?.hereZoneMaybe = newValue }
}

var gFavoritesHereMaybe: Zone? {
	get { return gRemoteStorage.maybeZoneForRecordName(gRemoteStorage.cloud(for: .favoritesID)?.hereRecordName) }    // all favorites are stored in mine
	set { gRemoteStorage.cloud(for: .favoritesID)?.hereZoneMaybe = newValue }
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

var gClipBreadcrumbs : Bool {
	get { return getPreferencesBool(   for: kClipBreadcrumbs, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kClipBreadcrumbs) }
}

var gSkillLevel : ZSkillLevel {
	get { return  ZSkillLevel(rawValue: getPreferencesInt(for: kSkillLevel, defaultInt: kBeginnerSkillLevel) ?? kBeginnerSkillLevel) ?? ZSkillLevel.explorer }
	set { setPreferencesInt(newValue.rawValue, for: kSkillLevel); gMainController?.updateForSkillLevel() }
}

var gStartupLevel : ZStartupLevel {
	get { return  ZStartupLevel(rawValue: getPreferencesInt(for: kStartupLevel, defaultInt: kFirstTimeStartupLevel) ?? kFirstTimeStartupLevel) ?? ZStartupLevel.firstTime }
	set { setPreferencesInt(newValue.rawValue, for: kStartupLevel) }
}

var gColorfulMode : Bool {
	get { return getPreferencesBool(   for: kColorfulMode, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kColorfulMode) }
}

var gShowFavorites : Bool {
	get { return getPreferencesBool(   for: kShowFavorites, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kShowFavorites) }
}

var gHereRecordNames: String {
    get { return getPreferenceString(    for: kHereRecordIDs) { return kTutorialRecordName + kColonSeparator + kRootName }! }
    set { setPreferencesString(newValue, for: kHereRecordIDs) }
}

var gAuthorID: String? {    // persist for file read on launch
    get { return getPreferenceString(    for: kAuthorID) { return nil } }
    set { setPreferencesString(newValue, for: kAuthorID) }
}

var gUserRecordID: String? {    // persist for file read on launch
    get { return getPreferenceString(    for: kUserRecordID) }
    set { setPreferencesString(newValue, for: kUserRecordID) }
}

var gUserRecord: CKRecord? {    // persist for file read on launch
	get {
		if  let  recordName = gUserRecordID,
			let    storable = getPreferenceString(for: kUserRecord) {
			let      record = CKRecord(recordType: kUserType, recordID: CKRecord.ID(recordName: recordName))
			record.storable = storable

			return record
		}

		return nil
	}

	set { setPreferencesString(newValue?.storable, for: kUserRecord) }
}

var gEmailTypesSent: String {
    get {
        let pref = getPreferenceString(for: kEmailTypesSent) ?? ""
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

var gFavoritesAreVisible: Bool {
	get { return getPreferencesBool(   for: kFavoritesAreVisibleKey, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kFavoritesAreVisibleKey) }
}

var gAccentColor: ZColor {
	get { return !gColorfulMode ? kLightGrayColor : getPreferencesColor( for: kAccentColorKey, defaultColor: ZColor(red: 241.0/256.0, green: 227.0/256.0, blue: 206.0/256.0, alpha: 1.0)) }
	set { setPreferencesColor(newValue, for: kAccentColorKey) }
}

var gActiveColor: ZColor {
	get { return !gColorfulMode ? kDarkGrayColor : getPreferencesColor( for: kActiveColorKey, defaultColor: ZColor.purple.darker(by: 1.5)) }
	set { setPreferencesColor(newValue, for: kActiveColorKey) }
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

var gWindowRect: CGRect {
	get { return getPreferencesRect(for: kWindowRectKey, defaultRect: kDefaultWindowRect) }
	set { setPreferencesRect(newValue, for: kWindowRectKey) }
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

var gFavoritesMode: ZFavoritesMode {
	get {
		let value  = UserDefaults.standard.object(forKey: kFavoritesMode) as? String
		var mode   = ZFavoritesMode.favorites

		if  value != nil {
			mode   = ZFavoritesMode(rawValue: value!)!
		} else {
			UserDefaults.standard.set(mode.rawValue, forKey:kFavoritesMode)
			UserDefaults.standard.synchronize()
		}

		return mode
	}

	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kFavoritesMode)
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
		var state: ZDetailsViewID?
		
		if  let object = UserDefaults.standard.object(forKey:kDetailsState) {
			state      = ZDetailsViewID(rawValue: object as! Int)
		}
		
		if  state     == nil {
			state      = .Explore
			
			UserDefaults.standard.set(state!.rawValue, forKey:kDetailsState)
			UserDefaults.standard.synchronize()
		}
		
		return state!
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

var gCurrentGraph : ZFunction {
	get {
		var graph: ZFunction?
		
		if  let object = UserDefaults.standard.object(forKey:kCurrentGraph) {
			graph      = ZFunction(rawValue: object as! String)
		}
		
		if  graph     == nil {
			graph      = .eMe
			
			UserDefaults.standard.set(graph!.rawValue, forKey:kActionFunction)
			UserDefaults.standard.synchronize()
		}
		
		return graph!
	}

	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kCurrentGraph)
		UserDefaults.standard.synchronize()
	}
}

#endif

var gWorkMode: ZWorkMode = .startupMode {
	didSet {
		if  gCanSaveWorkMode {
			setPreferencesString(gWorkMode.rawValue, for: kWorkMode)
		}
	}
}

var gCurrentEssay: ZNote? {
	didSet {
		gRecents.push(intoNotes: true)
		setPreferencesString(gCurrentEssay?.identifier() ?? "", for: kCurrentEssay)
	}
}

// MARK:- timers
// MARK:-

func gTemporarilySetKey(_ key: String, for seconds: Double = 1.0) {
	gCurrentKeyPressed = key

	gTimers.resetTimer(for: .tKey, withTimeInterval: seconds) { iTimer in
		gCurrentKeyPressed = ""
	}
}

func gTemporarilySetMouseZone(_ zone: Zone?, for seconds: Double = 0.5) {
	gCurrentMouseDownZone = zone

	gTimers.resetTimer(for: .tMouseZone, withTimeInterval: seconds) { iTimer in
		gCurrentMouseDownZone = nil
	}
}

func gTemporarilySetMouseDownLocation(_ location: CGFloat?, for seconds: Double = 1.0) {
	gCurrentMouseDownLocation = location

	gTimers.resetTimer(for: .tMouseLocation, withTimeInterval: seconds) { iTimer in
		gCurrentMouseDownLocation = nil
	}
}

func gTemporarilySetArrowsDoNotBrowse(_ notBrowse: Bool, for seconds: Double = 1.0) {
	gArrowsDoNotBrowse = notBrowse

	gTimers.resetTimer(for: .tArrowsDoNotBrowse, withTimeInterval: seconds) { iTimer in
		gArrowsDoNotBrowse = false
	}
}

// MARK:- actions
// MARK:-

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

var gLastLocation = NSPoint.zero

func gTestForUserInterrupt() throws {
	if !Thread.isMainThread {
//		gFOREGROUND.async {
//			try gTestForUserInterrupt()
//		}
	} else if  let w = gUserIsActive {
		printDebug(.dUser, "throwing user interrupt in \(w.description) \(gInterruptionCount)")
		gInterruptionCount += 1


		if !gHasFinishedStartup {
			gSignal([.sStartup])
		}

		throw(ZInterruptionError.userInterrupted)
	}
}

func gRefreshCurrentEssay() {
	if  let identifier = getPreferencesString(for: kCurrentEssay, defaultString: kTutorialRecordName),
		let      essay = gRecents.object(for: identifier) as? ZNote {
		gCurrentEssay  = essay
	}
}

func gRefreshPersistentWorkMode() {
	if  let     mode = getPreferencesString(for: kWorkMode, defaultString: ZWorkMode.noteMode.rawValue),
		let workMode = ZWorkMode(rawValue: mode) {
		gWorkMode    = workMode
	}
}

@discardableResult func toggleRingControlModes(isDirection: Bool) -> Bool {
	if isDirection {
		gListGrowthMode  = gListsGrowDown      ? .up  : .down
	} else {
		gConfinementMode = gBrowsingIsConfined ? .all : .list
	}

	return true
}

func toggleDatabaseID() {
	switch        gDatabaseID {
	case .mineID: gDatabaseID = .everyoneID
	default:      gDatabaseID = .mineID
	}
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

// MARK:- internals
// MARK:-

func getPreferencesAmount(for key: String, defaultAmount: CGFloat = 0.0) -> CGFloat {
	return getPreferenceString(for: key) { return "\(defaultAmount)" }?.floatValue ?? defaultAmount
}

func setPreferencesAmount(_ iAmount: CGFloat = 0.0, for key: String) {
	setPreferencesString("\(iAmount)", for: key)
}

func getPreferencesSize(for key: String, defaultSize: CGSize = CGSize.zero) -> CGSize {
    return getPreferenceString(for: key) { return NSStringFromSize(defaultSize) }?.cgSize ?? defaultSize
}

func setPreferencesSize(_ iSize: CGSize = CGSize.zero, for key: String) {
    setPreferencesString(NSStringFromSize(iSize), for: key)
}

func getPreferencesRect(for key: String, defaultRect: CGRect = CGRect.zero) -> CGRect {
    return getPreferenceString(for: key) { return NSStringFromRect(defaultRect) }?.cgRect ?? defaultRect
}

func setPreferencesRect(_ iRect: CGRect = CGRect.zero, for key: String) {
    setPreferencesString(NSStringFromRect(iRect), for: key)
}

func getPreferencesColor(for key: String, defaultColor: ZColor) -> ZColor {
    var color = defaultColor

    if  let data = UserDefaults.standard.object(forKey: key) as? Data,
		let    c = NSKeyedUnarchiver.unarchiveObject(with: data) as? ZColor {
        color    = c
    } else {
        setPreferencesColor(color, for: key)
    }

    return color.accountingForDarkMode
}

func setPreferencesColor(_ color: ZColor, for key: String) {
	let data: Data = NSKeyedArchiver.archivedData(withRootObject: color.accountingForDarkMode)

    UserDefaults.standard.set(data, forKey: key)
    UserDefaults.standard.synchronize()
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

func getPreferencesInt(for key: String, defaultInt: Int?) -> Int? {
	if  let         i = defaultInt,
		let    string = getPreferencesString(for: key, defaultString: "\(i)") {
		return string.integerValue
	}

	return defaultInt
}

func setPreferencesInt(_ iInt: Int?, for key: String) {
	if  let i = iInt {
		UserDefaults.standard.set("\(i)", forKey: key)
		UserDefaults.standard.synchronize()
	}
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