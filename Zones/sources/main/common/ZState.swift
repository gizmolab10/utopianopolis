//
//  ZState.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

#if os(OSX)
import Cocoa
let gFontDelta = 15.0
var gTextOffset: CGFloat?
#elseif os(iOS)
import UIKit
let gFontDelta = 17.0
var gTextOffset: CGFloat? { return gTextEditor.cursorOffset }
#endif


var                gWorkMode                     = ZWorkMode.startupMode
var             gDeferRedraw                     = false
var             gDebugReport                     = false
var           gTextCapturing                     = false
var      	  gShowThoughtsGraph					 = false
var         gIsReadyToShowUI                     = false
var       gKeyboardIsVisible                     = false
var       gArrowsDoNotBrowse                     = false
var      gShowShortcutWindow                     = false
var      gDebugDenyOwnership                     = false
var    gDebugShowIdentifiers                     = false
var   gMeasureOpsPerformance                     = true
var     gTimeOfSystemStartup                     = Date.timeIntervalSinceReferenceDate
var   gTimeUntilCurrentEvent:       TimeInterval = 0  // by definition, first event IS startup
var      gCurrentBrowseLevel:               Int?
var         gDragDropIndices: NSMutableIndexSet?
var            gDragRelation:         ZRelation?
var            gDragDropZone:              Zone?
var             gDraggedZone:              Zone?
var               gDragPoint:           CGPoint?
var                gExpanded:          [String]?

var                gDarkMode:     InterfaceStyle { return InterfaceStyle() }
var                  gIsDark:               Bool { return gDarkMode == .Dark }
var                  gIsLate:               Bool { return gBatches.isLate }
var              gIsDragging:               Bool { return gDraggedZone != nil }
var    gIsShortcutsFrontmost:               Bool { return gShortcuts?.view.window?.isKeyWindow ?? false }
var      gBrowsingIsConfined:               Bool { return gBrowsingMode == .confined }
var        gInsertionsFollow:               Bool { return gInsertionMode == .follow }
var          gDuplicateEvent:               Bool { return gCurrentEvent != nil && (gTimeSinceCurrentEvent < 0.4) }
var   gTimeSinceCurrentEvent:       TimeInterval { return Date.timeIntervalSinceReferenceDate - gTimeUntilCurrentEvent }
var                gDragView:         ZDragView? { return gGraphController?.dragView }
var               gDotHeight:             Double { return Double(gGenericOffset.height / 2.5 + 13.0) }
var                gDotWidth:             Double { return gDotHeight * 0.75 }
var      gChildrenViewOffset:             Double { return gDotWidth + Double(gGenericOffset.height) * 1.2 }
var                gFontSize:            CGFloat { return gGenericOffset.height + CGFloat(gFontDelta) } // height 2 .. 20
var              gWidgetFont:              ZFont { return .systemFont(ofSize: gFontSize) }
var           gFavoritesFont:              ZFont { return .systemFont(ofSize: gFontSize * kFavoritesReduction) }
var        gDefaultTextColor:             ZColor { return (gIsDark && !gIsPrinting) ? kWhiteColor : ZColor.black }
var   gDarkerBackgroundColor:            CGColor { return gBackgroundColor.darker  (by: 4.0)  .cgColor }
var  gDarkishBackgroundColor:            CGColor { return gBackgroundColor.darkish (by: 1.028).cgColor }
var gDirectionIndicatorColor:            CGColor { return gBackgroundColor.darker  (by: 1.3)  .cgColor }
var gLightishBackgroundColor:            CGColor { return gBackgroundColor.lightish(by: 1.02) .cgColor }
var  gLighterBackgroundColor:            CGColor { return gBackgroundColor.lighter (by: 4.0)  .cgColor }


func toggleMode(isDirection: Bool) {
    if  isDirection {
        gInsertionMode = gInsertionsFollow   ? .precede     : .follow
    } else {
        gBrowsingMode  = gBrowsingIsConfined ? .cousinJumps : .confined
    }
}


var gCurrentEvent: ZEvent? {
    didSet {
        gTimeUntilCurrentEvent = Date.timeIntervalSinceReferenceDate
    }
}


func toggleDatabaseID() {
    switch        gDatabaseID {
    case .mineID: gDatabaseID = .everyoneID
    default:      gDatabaseID = .mineID
    }
}


// MARK:- persistence
// MARK:-


var gExpandedZones : [String] {
    get {
        if  gExpanded == nil {
            let  value = getPreferencesString(for: kExpandedZones, defaultString: "")
            gExpanded  = value?.components(separatedBy: kSeparator)
        }

        return gExpanded!
    }

    set {
        gExpanded = newValue

        setPreferencesString(newValue.joined(separator: kSeparator), for: kExpandedZones)
    }
}


var gHere: Zone {
    get { return gCloud!.hereZone }
    set { gCloud?.hereZone = newValue }
}


var gHereMaybe: Zone? {
    get { return gCloud?.hereZoneMaybe }
    set { gCloud?.hereZoneMaybe = newValue }
}


var gMathewStyleUI : Bool {
    get { return getPreferencesBool(   for: kMathewStyle, defaultBool: false) }
    set { setPreferencesBool(newValue, for: kMathewStyle) }
}


var gShowDebugDetails : Bool {
    get { return getPreferencesBool(   for: kDebugDetails, defaultBool: false) }
    set { setPreferencesBool(newValue, for: kDebugDetails) }
}


var gHereRecordNames: String {
    get { return getPreferenceString(    for: kHereRecordIDs) { return kRootName + kSeparator + kRootName }! }
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


func emailSent(for type: ZSentEmailType) -> Bool {
    return gEmailTypesSent.contains(type.rawValue)
}


func recordEmailSent(for type: ZSentEmailType) {
    if  !emailSent  (for: type) {
        gEmailTypesSent.append(type.rawValue)
    }
}


var gFavoritesAreVisible: Bool {
    get { return getPreferencesBool(   for: kFavoritesAreVisibleKey, defaultBool: false) }
    set { setPreferencesBool(newValue, for: kFavoritesAreVisibleKey) }
}


var gBackgroundColor: ZColor {
    get { return   getPreferencesColor( for: kBackgroundColorKey, defaultColor: ZColor(hue: 0.6, saturation: 0.1, brightness: kUnselectBrightness, alpha: 1)) }
    set { setPreferencesColor(newValue, for: kBackgroundColorKey) }
}


var gRubberbandColor: ZColor {
    get { return   getPreferencesColor( for: kRubberbandColorKey, defaultColor: ZColor.purple.darker(by: 1.5)) }
    set { setPreferencesColor(newValue, for: kRubberbandColorKey) }
}


var gGenericOffset: CGSize {
    get {
		var offset = getPreferencesSize(for: kGenericOffsetKey, defaultSize: CGSize(width: 30.0, height: 2.0))
		
		if kIsPhone {
			offset.height += 5.0
		}
		
		return offset
	}
    set { setPreferencesSize(newValue, for: kGenericOffsetKey) }
}


var gWindowRect: CGRect {
    get { return getPreferencesRect(for: kWindowRectKey, defaultRect: kDefaultWindowRect) }
    set { setPreferencesRect(newValue, for: kWindowRectKey) }
}


var gScrollOffset: CGPoint {
    get {
        let  point = CGPoint(x: 0.0, y: 0.0)
        let string = getPreferenceString(for: kScrollOffsetKey) { return NSStringFromPoint(point) }

        return string?.cgPoint ?? point
    }

    set {
        let string = NSStringFromPoint(newValue)

        setPreferencesString(string, for: kScrollOffsetKey)
    }
}


var gBrowsingMode: ZBrowsingMode {
    get {
        let value  = UserDefaults.standard.object(forKey: kBrowsingMode) as? Int
        var mode   = ZBrowsingMode.confined
        
        if  value != nil {
            mode   = ZBrowsingMode(rawValue: value!)!
        } else {
            UserDefaults.standard.set(mode.rawValue, forKey:kBrowsingMode)
            UserDefaults.standard.synchronize()
        }
        
        return mode
    }
    
    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:kBrowsingMode)
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

        if value == nil {
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


var gInsertionMode: ZInsertionMode {
    get {
        var mode: ZInsertionMode?

        if let object = UserDefaults.standard.object(forKey:kInsertionMode) {
            mode      = ZInsertionMode(rawValue: object as! Int)
        }

        if  mode == nil {
            mode      = .follow

            UserDefaults.standard.set(mode!.rawValue, forKey:kInsertionMode)
            UserDefaults.standard.synchronize()
        }

        return mode!
    }

    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:kInsertionMode)
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

        if let object = UserDefaults.standard.object(forKey:kDetailsState) {
            state     = ZDetailsViewID(rawValue: object as! Int)
        }

        if state == nil {
            state     = .All

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


// MARK:- internals
// MARK:-


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

    if  let data = UserDefaults.standard.object(forKey: key) as? Data, let c = NSKeyedUnarchiver.unarchiveObject(with: data) as? ZColor {
        color = c
    } else {
        setPreferencesColor(color, for: key)
    }
    
    if  gIsDark {
        color = color.inverted
    }

    return color
}


func setPreferencesColor(_ iColor: ZColor, for key: String) {
    var color = iColor
    
    if  gIsDark {
        color = color.inverted
    }

    let data: Data = NSKeyedArchiver.archivedData(withRootObject: color)

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


