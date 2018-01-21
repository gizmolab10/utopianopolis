//
//  ZState.swift
//  Zones
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZInsertionMode: Int {
    case precede
    case follow
}


enum ZFileMode: Int {
    case local
    case cloud
}


enum ZWorkMode: Int {
    case startupMode
    case searchMode
    case graphMode
    case essayMode
}


enum ZCountsMode: Int {
    case none
    case dots
    case fetchable
    case progeny
}



enum ZStorageMode: String {
    case favoritesMode = "favorites"
    case  everyoneMode = "everyone"
    case    sharedMode = "group"
    case      mineMode = "mine"
}


struct ZDetailsViewID: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let Information = ZDetailsViewID(rawValue: 1 << 0)
    static let Preferences = ZDetailsViewID(rawValue: 1 << 1)
    static let   Favorites = ZDetailsViewID(rawValue: 1 << 2)
    static let       Cloud = ZDetailsViewID(rawValue: 1 << 3)
    static let        Help = ZDetailsViewID(rawValue: 1 << 4)
    static let         All = ZDetailsViewID(rawValue: 0xFFFF)
}


let          gClearColor                     = ZColor(white: 1.0, alpha: 0.0)
var            gWorkMode                     = ZWorkMode.startupMode
var            gFileMode                     = ZFileMode.cloud
var       gTextCapturing                     = false
var     gShowIdentifiers                     = false
var    gCloudUnavailable                     = false
var   gCrippleUserAccess                     = false
var   gKeyboardIsVisible                     = false
var     gDebugOperations                     = true
var     gDebugTimerCount                     = 0
var     gDragDropIndices: NSMutableIndexSet? = nil
var        gDragRelation:         ZRelation? = nil
var        gDragDropZone:              Zone? = nil
var         gDraggedZone:              Zone? = nil
var          gDebugTimer:             Timer? = nil
var           gDragPoint:           CGPoint? = nil

var              gIsLate:               Bool { return gCloudUnavailable || gDBOperationsManager.isLate }
var          gIsDragging:               Bool { return gDraggedZone != nil }
var       gIsEditingText:               Bool { return gEditorView?.window?.firstResponder?.isKind(of: ZTextView.self) ?? false }
var    gInsertionsFollow:               Bool { return gInsertionMode == .follow }
var  gHasPrivateDatabase:               Bool { return gUserRecordID != nil }
var    gEditorController: ZEditorController? { return gControllersManager.controllerForID(.editor) as? ZEditorController }
var          gEditorView:      ZoneDragView? { return gEditorController?.editorView }
var           gDotHeight:             Double { return Double(gGenericOffset.height / 2.5 + 13.0) }
var            gDotWidth:             Double { return gDotHeight * 0.75 }
var             fontSize:            CGFloat { return gGenericOffset.height + CGFloat(15.0) } // height 2 .. 20
var          gWidgetFont:              ZFont { return .systemFont(ofSize: fontSize) }
var       gFavoritesFont:              ZFont { return .systemFont(ofSize: fontSize * kReductionRatio) }


// MARK:- persistence
// MARK:-


var gUserRecordID: String? {
    get { return getPreferencesString(   for: kUserRecordID, defaultString: nil) }
    set { setPreferencesString(newValue, for: kUserRecordID) }
}


var gFavoritesAreVisible: Bool {
    get { return getPreferencesBool(   for: kfavoritesVisible, defaultBool: false) }
    set { setPreferencesBool(newValue, for: kfavoritesVisible) }
}


var gActionsAreVisible: Bool {
    get { return getPreferencesBool(   for: kActionsVisible, defaultBool: false) }
    set { setPreferencesBool(newValue, for: kActionsVisible) }
}


var gBackgroundColor: ZColor {
    get { return   getPreferencesColor( for: kBackgroundColor, defaultColor: ZColor(hue: 0.6, saturation: 0.1, brightness: kUnselectBrightness, alpha: 1)) }
    set { setPreferencesColor(newValue, for: kBackgroundColor) }
}


var gRubberbandColor: ZColor {
    get { return   getPreferencesColor( for: kRubberbandColor, defaultColor: ZColor.purple.darker(by: 1.5)) }
    set { setPreferencesColor(newValue, for: kRubberbandColor) }
}


var gGenericOffset: CGSize {
    get {
        let size = CGSize(width: 30.0, height: 2.0)

        return getPreferencesString( for: kGenericOffset, defaultString: NSStringFromSize(size))?.cgSize ?? size
    }

    set {
        let string = NSStringFromSize(newValue)

        setPreferencesString(string, for: kGenericOffset)
    }
}


var gScrollOffset: CGPoint {
    get {
        let point = CGPoint(x: 0.0, y: 0.0)

        return getPreferencesString( for: kScrollOffset, defaultString: NSStringFromPoint(point))?.cgPoint ?? point
    }

    set {
        let string = NSStringFromPoint(newValue)

        setPreferencesString(string, for: kScrollOffset)
    }
}


var gCountsMode: ZCountsMode {
    get {
        var  mode  = ZCountsMode.dots
        let value  = UserDefaults.standard.object(forKey: kCountsMode) as? Int

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
        var mode: ZInsertionMode? = nil

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


var gStorageMode: ZStorageMode {
    get {
        var mode: ZStorageMode? = nil

        if let object = UserDefaults.standard.object(forKey:kStorageMode) {
            mode      = ZStorageMode(rawValue: object as! String)
        }

        if  mode     == nil || !gHasPrivateDatabase {
            mode      = .everyoneMode

            UserDefaults.standard.set(mode!.rawValue, forKey:kStorageMode)
            UserDefaults.standard.synchronize()
        }

        return mode!
    }

    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:kStorageMode)
        UserDefaults.standard.synchronize()
    }
}


var gDetailsViewIDs: ZDetailsViewID {
    get {
        var state: ZDetailsViewID? = nil

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


func getPreferencesColor(for key: String, defaultColor: ZColor) -> ZColor {
    if  let data = UserDefaults.standard.object(forKey: key) as? Data, let color = NSKeyedUnarchiver.unarchiveObject(with: data) as? ZColor {
        return color
    }

    setPreferencesColor(defaultColor, for: key)

    return defaultColor
}


func setPreferencesColor(_ iColor: ZColor, for key: String) {
    let data: Data = NSKeyedArchiver.archivedData(withRootObject: iColor)

    UserDefaults.standard.set(data, forKey: key)
    UserDefaults.standard.synchronize()
}


func getPreferencesString(for key: String, defaultString: String?) -> String? {
    if  let    string = UserDefaults.standard.object(forKey: key) as? String {
        return string
    }

    if  let    string = defaultString {
        setPreferencesString(string, for: key)
    }

    return defaultString
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


