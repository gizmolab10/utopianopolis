//
//  ZState.swift
//  Zones
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZGraphAlteringMode: Int {
    case task
    case essay
}


enum ZFileMode: Int {
    case local
    case cloud
}


enum ZWorkMode: Int {
    case searchMode
    case essayMode
    case editMode
}


struct ZSettingsState: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let        Help = ZSettingsState(rawValue: 1 << 0)
    static let Preferences = ZSettingsState(rawValue: 1 << 1)
    static let Information = ZSettingsState(rawValue: 1 << 2)
    static let     Actions = ZSettingsState(rawValue: 1 << 3)
    static let         All = ZSettingsState(rawValue: 0xFFFF)
}


var recursivelyExpand = false
var    gShowsSearching = false
var     textCapturing = false
var          fileMode = ZFileMode.cloud
var          workMode = ZWorkMode.editMode
var gGraphAlteringMode = ZGraphAlteringMode.task
var     gGenericOffset = CGSize(width: 12.0, height: 4.0)
var         gDotHeight = 12.0


var               asTask:   Bool { get { return gGraphAlteringMode == .task    } }
var grabbedBookmarkColor: ZColor { get { return gBookmarkColor.darker(by: 1.5) } }
var     grabbedTextColor: ZColor { get { return gZoneColor    .darker(by: 1.8) } }


// MARK:- persistence
// MARK:-


let       zoneColorKey = "zone color"
let   bookmarkColorKey = "bookmark color"
let backgroundColorKey = "background color"
let     storageModeKey = "current storage mode"
let   settingsStateKey = "current settings state"
let   lineThicknessKey = "line thickness"


func getColorForKey(_ key: String, defaultColor: ZColor) -> ZColor {
    if let data = UserDefaults.standard.object(forKey: key) as? Data, let color = NSKeyedUnarchiver.unarchiveObject(with: data) as? ZColor {
        return color
    }

    setColor(defaultColor, key: key)

    return defaultColor
}


func setColor(_ iColor: ZColor, key: String) {
    let data: Data = NSKeyedArchiver.archivedData(withRootObject: iColor)

    UserDefaults.standard.set(data, forKey: key)
    UserDefaults.standard.synchronize()
}


var gZoneColor: ZColor {
    set { setColor(newValue, key: zoneColorKey) }
    get { return   getColorForKey(zoneColorKey, defaultColor: ZColor.purple) }
}


var gBookmarkColor: ZColor {
    set { setColor(newValue, key: bookmarkColorKey) }
    get { return   getColorForKey(bookmarkColorKey, defaultColor: ZColor.blue) }
}


var gBackgroundColor: ZColor {
    set { setColor(newValue, key: backgroundColorKey) }
    get { return   getColorForKey(backgroundColorKey, defaultColor: ZColor(hue: 0.6, saturation: 0.0, brightness: unselectBrightness, alpha: 1)) }
}


var gLineThickness: Double {
    set {
        UserDefaults.standard.set(newValue, forKey:lineThicknessKey)
        UserDefaults.standard.synchronize()
    }

    get {
        var value: Double? = UserDefaults.standard.object(forKey: lineThicknessKey) as? Double

        if value == nil {
            value = 1.25

            UserDefaults.standard.set(value, forKey:lineThicknessKey)
            UserDefaults.standard.synchronize()
        }

        return value!
    }
}


var gStorageMode: ZStorageMode {
    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:storageModeKey)
        UserDefaults.standard.synchronize()
    }

    get {
        var mode: ZStorageMode? = nil

        if let object = UserDefaults.standard.object(forKey:storageModeKey) {
            mode      = ZStorageMode(rawValue: object as! String)
        }

        if mode == nil {
            mode      = .everyone

            UserDefaults.standard.set(mode!.rawValue, forKey:storageModeKey)
            UserDefaults.standard.synchronize()
        }

        return mode!
    }
}


var gSettingsState: ZSettingsState {
    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:settingsStateKey)
        UserDefaults.standard.synchronize()
    }

    get {
        var state: ZSettingsState? = nil

        if let object = UserDefaults.standard.object(forKey:settingsStateKey) {
            state     = ZSettingsState(rawValue: object as! Int)
        }

        if state == nil {
            state     = .All

            UserDefaults.standard.set(state!.rawValue, forKey:settingsStateKey)
            UserDefaults.standard.synchronize()
        }

        return state!
    }
}
