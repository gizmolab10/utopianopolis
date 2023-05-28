//
//  ZState+Persistent.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/3/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

func gUpdatePersistence() {
	if !gCDUseExistingStores {  // if we erase stores, we should also erase old record names, but above will also erase them
		gClearHereRecordNames()
	}
}

func gClearHereRecordNames() {
	setPreferencesString(kDefaultRecordNames, for: kHereRecordNames)
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
	get { return getPreferencesBool(   for: kShowDetails, defaultBool: true) }
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

var gShowFavoritesMapForIOS : Bool {
	get { return getPreferencesBool(   for: kShowFavoritesMap, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kShowFavoritesMap) }
}

var gShowExplanations : Bool {
	get { return getPreferencesBool(   for: kShowExplanations, defaultBool: true) }
	set { setPreferencesBool(newValue, for: kShowExplanations) }
}

var gShowMainControls : Bool {
	get { return getPreferencesBool(   for: kShowMainControls, defaultBool: true) }
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

var gStartupCount : Int {
	get { return getPreferencesInt(for: kStartupCount, defaultInt: 0) }
	set { setPreferencesInt(newValue, for: kStartupCount) }
}

var gHereRecordNames: String {
	get { return getPreferenceString(    for: kHereRecordNames) { return kDefaultRecordNames }! }
	set { setPreferencesString(newValue, for: kHereRecordNames) }
}

var gAuthorID: String? {    // persist for file read on launch
	get { return getPreferenceString(    for: kAuthorID) { return nil } }
	set { setPreferencesString(newValue, for: kAuthorID) }
}

var gWindowRect: CGRect {
	get { return getPreferencesRect(for: kWindowRectKey, defaultRect: kDefaultWindowRect) }
	set { setPreferencesRect(newValue, for: kWindowRectKey) }
}

var gAccentColor: ZColor {
	get { return !gColorfulMode ? gIsDark ? kDarkerGrayColor : kLighterGrayColor : getPreferencesColor( for: kAccentColorKey, defaultColor: ZColor(red: 241.0/256.0, green: 227.0/256.0, blue: 206.0/256.0, alpha: 1.0)) }
	set { setPreferencesColor(newValue, for: kAccentColorKey) }
}

var gActiveColor: ZColor {
	get { return !gColorfulMode ? kGrayColor : getPreferencesColor( for: kActiveColorKey, defaultColor: ZColor.purple.darker(by: 1.5)) }
	set { setPreferencesColor(newValue, for: kActiveColorKey) }
}

var gEssayTitleMode : ZEssayTitleMode {
	get { return ZEssayTitleMode(rawValue: getPreferencesInt(for: kEssayTitleMode, defaultInt: ZEssayTitleMode.sFull.rawValue))! }
	set { setPreferencesInt(newValue.rawValue, for: kEssayTitleMode) }
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

struct ZSearchFilter: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let fBookmarks = ZSearchFilter(rawValue: 1 << 0)
	static let     fNotes = ZSearchFilter(rawValue: 1 << 1)
	static let     fIdeas = ZSearchFilter(rawValue: 1 << 2)
	static let      fNone = ZSearchFilter([])
	static let       fAll = ZSearchFilter(rawValue: 7)
}

var gSearchFilter: ZSearchFilter {
	get { return ZSearchFilter(rawValue: getPreferencesInt(for: kSearchFilter, defaultInt: ZSearchFilter.fAll.rawValue)) }
	set { setPreferencesInt(newValue.rawValue, for: kSearchFilter) }
}

struct ZSearchScope: OptionSet {
	let  rawValue : Int
	init(rawValue : Int) { self.rawValue = rawValue }

	static let      sNone =  ZSearchScope([])
	static let      sMine =  ZSearchScope(rawValue: 1 << 0)
	static let    sPublic =  ZSearchScope(rawValue: 1 << 1)
//	static let    sShared =  ZSearchScope(rawValue: 1 << 2) // if this is commented out, the following must continue sequence, NOT skip this raw value
	static let sFavorites =  ZSearchScope(rawValue: 1 << 2)
	static let    sOrphan =  ZSearchScope(rawValue: 1 << 3)
	static let     sTrash =  ZSearchScope(rawValue: 1 << 4)
	static var        all : [ZSearchScope]                  { return [.sMine, .sPublic, .sFavorites, .sOrphan, .sTrash] }
}

var gSearchScope: ZSearchScope {
	get { return ZSearchScope(rawValue: getPreferencesInt(for: kSearchScope, defaultInt: ZSearchScope.sMine.rawValue)) }
	set { setPreferencesInt(newValue.rawValue, for: kSearchScope) }
}

var gCKRepositoryID: ZCKRepositoryID {
	get {
		let  defaultID = ZCKRepositoryID.rSubmitted      // repository of Seriously in the app store
		if  let string = getPreferencesString(for: kCKRepositoryID, defaultString: defaultID.rawValue ),
			let     id = ZCKRepositoryID(rawValue: string) {
			return  id
		}

		return defaultID
	}

	set {
		setPreferencesString(newValue.rawValue, for: kCKRepositoryID)

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

var gDatabaseID: ZDatabaseID {
	get {
		var databaseID: ZDatabaseID?

		if let object   = UserDefaults.standard.object(forKey:kDatabaseID) {
			databaseID  = ZDatabaseID(rawValue: object as! String)
		}

		if  databaseID   == nil {
			databaseID  = .everyoneID

			UserDefaults.standard.set(databaseID!.rawValue, forKey:kDatabaseID)
			UserDefaults.standard.synchronize()
		}

		return databaseID!
	}

	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kDatabaseID)
		UserDefaults.standard.synchronize()
	}
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

// MARK: - growth (direction & confinement)
// MARK: -

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

@discardableResult func toggleGrowthAndConfinementModes(changesDirection: Bool) -> Bool {
	if  changesDirection {
		gListGrowthMode  = gListsGrowDown      ? .up  : .down
	} else {
		gConfinementMode = gBrowsingIsConfined ? .all : .list
	}

	return true
}

// MARK: - show and hide
// MARK: -

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
			gCollapsed  = value?.componentsSeparatedByColon
		}

		return gCollapsed!
	}

	set {
		gCollapsed = newValue

		setPreferencesString(newValue.joinedWithColon, for: kCollapsedIdeas)
	}
}

var gExpandedIdeas : StringsArray {
	get {
		if  gExpanded == nil {
			let value  = getPreferencesString(for: kExpandedIdeas, defaultString: kEmpty)
			gExpanded  = value?.componentsSeparatedByColon
		}

		return gExpanded!
	}

	set {
		gExpanded = newValue

		setPreferencesString(newValue.joinedWithColon, for: kExpandedIdeas)
	}
}

// MARK: - details
// MARK: -

var gHiddenDetailViewIDs: ZDetailsViewID {
	get {
		var viewID: ZDetailsViewID?

		if  let object = UserDefaults.standard.object(forKey:kDetailsState) {
			viewID     = ZDetailsViewID(rawValue: object as! Int)
		}

		if  viewID    == nil {
			viewID     = [.vData, .vPreferences, .vSubscribe, .vKickoffTools]

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

func gDetailsViewIsVisible(for id: ZDetailsViewID) -> Bool {
	return gShowDetailsView && (gDetailsController?.viewIsVisible(for: id) ?? false)
}

enum ZWorkMode: String {
	case wEditIdeaMode = "e"
	case wStartupMode  = "s"
	case wResultsMode  = "?"
	case wEssayMode    = "n"
	case wMapMode      = "m"
}

var gWorkMode: ZWorkMode = .wStartupMode {
	didSet {
		if  gCanSaveWorkMode, gAllowSavingWorkMode {
			setPreferencesString(gWorkMode.rawValue, for: kWorkMode)
		}
	}
}

func gRefreshPersistentWorkMode() {
	if  let             mode = getPreferencesString(for: kWorkMode, defaultString: ZWorkMode.wMapMode.rawValue),
		let         workMode = ZWorkMode(rawValue: mode) {
		gWorkMode            = workMode
		gAllowSavingWorkMode = true
	}
}

// MARK: - essay
// MARK: -

var gCurrentEssay: ZNote? {
	didSet {
		setPreferencesString(gCurrentEssay?.identifier() ?? kEmpty, for: kCurrentEssay)
	}
}

var gAdjustedEssayTitleMode: ZEssayTitleMode {
	let isNote = (gCurrentEssay?.childrenNotes.count ?? 0) == 0
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

func gRefreshCurrentEssay() {
	if  let identifier = getPreferencesString(for: kCurrentEssay, defaultString: kTutorialRecordName),
		let      essay = gFavoritesCloud.object(for: identifier) as? ZNote {
		gCurrentEssay  = essay
	}
}

// MARK: - starburst
// MARK: -

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

var gCirclesDisplayMode: ZCirclesDisplayMode {
	get {
		let value = UserDefaults.standard.object(    forKey: kCirclesDisplayMode) as? Int ?? 0

		return ZCirclesDisplayMode(rawValue: value)
	}
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey: kCirclesDisplayMode)
		UserDefaults.standard.synchronize()
	}
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
	if  gIsMainThread {
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

// MARK: - email
// MARK: -

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
		printDebug(.dError, "\(error)")
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
	if  let    value: NSNumber = UserDefaults.standard.object(forKey: key) as? NSNumber {
		return value.boolValue
	}

	setPreferencesBool(defaultBool, for: key)

	return defaultBool
}

func setPreferencesBool(_ iBool: Bool, for key: String) {
	UserDefaults.standard.set(iBool, forKey: key)
	UserDefaults.standard.synchronize()
}
