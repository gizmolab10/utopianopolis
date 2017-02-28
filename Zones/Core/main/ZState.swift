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


struct ZSettingsViewID: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let        Help = ZSettingsViewID(rawValue: 1 << 0)
    static let Preferences = ZSettingsViewID(rawValue: 1 << 1)
    static let Information = ZSettingsViewID(rawValue: 1 << 2)
    static let  CloudTools = ZSettingsViewID(rawValue: 1 << 3)
    static let   Favorites = ZSettingsViewID(rawValue: 1 << 4)
    static let         All = ZSettingsViewID(rawValue: 0xFFFF)
}


var     gTextCapturing = false
var    gShowsSearching = false
var gRecursivelyFetch = false
var         gDotHeight = 12.0
var          gDotWidth = gDotHeight * 0.75
var          gWorkMode = ZWorkMode.editMode
var          gFileMode = ZFileMode.cloud


var               asTask:   Bool { get { return gGraphAlteringMode == .task    } }
var grabbedBookmarkColor: ZColor { get { return gBookmarkColor.darker(by: 1.5) } }
var     grabbedTextColor: ZColor { get { return gZoneColor    .darker(by: 1.8) } }


// MARK:- persistence
// MARK:-


let         zoneColorKey = "zone color"
let     bookmarkColorKey = "bookmark color"
let   backgroundColorKey = "background color"
let  dragTargetsColorKey = "drag targets color"
let graphAlteringModeKey = "graph altering mode"
let       storageModeKey = "current storage mode"
let     settingsStateKey = "current settings state"
let     lineThicknessKey = "line thickness"
let     genericOffsetKey = "generick offset"


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
    get { return   getColorForKey(zoneColorKey, defaultColor: ZColor.blue) }
}


var gBookmarkColor: ZColor {
    set { setColor(newValue, key: bookmarkColorKey) }
    get { return   getColorForKey(bookmarkColorKey, defaultColor: ZColor.green) }
}


var gBackgroundColor: ZColor {
    set { setColor(newValue, key: backgroundColorKey) }
    get { return   getColorForKey(backgroundColorKey, defaultColor: ZColor(hue: 0.6, saturation: 0.0, brightness: unselectBrightness, alpha: 1)) }
}


var gDragTargetsColor: ZColor {
    set { setColor(newValue, key: dragTargetsColorKey) }
    get { return   getColorForKey(dragTargetsColorKey, defaultColor: ZColor.red) }
}


var gGenericOffset: CGSize {
    set {
        let string = NSStringFromSize(newValue)

        UserDefaults.standard.set(string, forKey: genericOffsetKey)
        UserDefaults.standard.synchronize()
    }

    get {
        if let string = UserDefaults.standard.object(forKey: genericOffsetKey) as? String {
            return CGSizeFromString(string)
        }

        let defaultValue = CGSize(width: 24.0, height: 12.0)
        let       string = NSStringFromSize(defaultValue)

        UserDefaults.standard.set(string, forKey: genericOffsetKey)
        UserDefaults.standard.synchronize()

        return defaultValue
    }
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


var gGraphAlteringMode: ZGraphAlteringMode {
    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:graphAlteringModeKey)
        UserDefaults.standard.synchronize()
    }

    get {
        var mode: ZGraphAlteringMode? = nil

        if let object = UserDefaults.standard.object(forKey:graphAlteringModeKey) {
            mode      = ZGraphAlteringMode(rawValue: object as! Int)
        }

        if mode == nil {
            mode      = .task

            UserDefaults.standard.set(mode!.rawValue, forKey:graphAlteringModeKey)
            UserDefaults.standard.synchronize()
        }

        return mode!
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


var gSettingsViewIDs: ZSettingsViewID {
    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:settingsStateKey)
        UserDefaults.standard.synchronize()
    }

    get {
        var state: ZSettingsViewID? = nil

        if let object = UserDefaults.standard.object(forKey:settingsStateKey) {
            state     = ZSettingsViewID(rawValue: object as! Int)
        }

        if state == nil {
            state     = .All

            UserDefaults.standard.set(state!.rawValue, forKey:settingsStateKey)
            UserDefaults.standard.synchronize()
        }

        return state!
    }
}
