//
//  ZState.swift
//  Zones
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation

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
    case searchMode
    case essayMode
    case editMode
}


enum ZCountsMode: Int {
    case none
    case dots
    case fetchable
    case progeny
}



enum ZStorageMode: String {
    case favorites = "favorites"
    case everyone  = "everyone"
    case shared    = "group"
    case mine      = "mine"
}


struct ZSettingsViewID: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let Information = ZSettingsViewID(rawValue: 1 << 0)
    static let Preferences = ZSettingsViewID(rawValue: 1 << 1)
    static let   Favorites = ZSettingsViewID(rawValue: 1 << 2)
    static let       Cloud = ZSettingsViewID(rawValue: 1 << 3)
    static let        Help = ZSettingsViewID(rawValue: 1 << 4)
    static let         All = ZSettingsViewID(rawValue: 0xFFFF)
}


var  gTextCapturing = false
var gShowsSearching = false
var       gFileMode = ZFileMode.cloud
var       gWorkMode = ZWorkMode.editMode
let     gClearColor = ZColor(white: 1.0, alpha: 0.0)

var             gDotWidth:             Double { return gDotHeight * 0.75 }
var            gDotHeight:             Double { return Double(gGenericOffset.height / 2.5 + 13.0) }
var     gInsertionsFollow:               Bool { return gInsertionMode == .follow }
var     gEditorController: ZEditorController? { return gControllersManager.controllerForID(.editor)   as? ZEditorController }
var           gEditorView:      ZoneDragView? { return gEditorController?.editorView }


// MARK:- persistence
// MARK:-


var gBackgroundColor: ZColor {
    get { return   getColorForKey(backgroundColorKey, defaultColor: ZColor(hue: 0.6, saturation: 0.0, brightness: unselectBrightness, alpha: 1)) }
    set { setColor(newValue, key: backgroundColorKey) }
}


var gDragTargetsColor: ZColor {
    get { return   getColorForKey(dragTargetsColorKey, defaultColor: ZColor.red) }
    set { setColor(newValue, key: dragTargetsColorKey) }
}


var gGenericOffset: CGSize {
    get {
        if let string = UserDefaults.standard.object(forKey: genericOffsetKey) as? String {
            return string.cgSize
        }

        let defaultValue = CGSize(width: 24.0, height: 12.0)
        let       string = NSStringFromSize(defaultValue)

        UserDefaults.standard.set(string, forKey: genericOffsetKey)
        UserDefaults.standard.synchronize()

        return defaultValue
    }

    set {
        let string = NSStringFromSize(newValue)

        UserDefaults.standard.set(string, forKey: genericOffsetKey)
        UserDefaults.standard.synchronize()
    }
}


var gScrollOffset: CGPoint {
    get {
        if let string = UserDefaults.standard.object(forKey: scrollOffsetKey) as? String {
            return string.cgPoint
        }

        let defaultValue = CGPoint(x: 0.0, y: 0.0)
        let       string = NSStringFromPoint(defaultValue)

        UserDefaults.standard.set(string, forKey: scrollOffsetKey)
        UserDefaults.standard.synchronize()

        return defaultValue
    }

    set {
        let string = NSStringFromPoint(newValue)

        UserDefaults.standard.set(string, forKey: scrollOffsetKey)
        UserDefaults.standard.synchronize()
    }
}


var gCountsMode: ZCountsMode {
    get {
        var  mode  = ZCountsMode.dots
        let value  = UserDefaults.standard.object(forKey: countsModeKey) as? Int

        if  value != nil {
            mode   = ZCountsMode(rawValue: value!)!
        } else {
            UserDefaults.standard.set(mode.rawValue, forKey:countsModeKey)
            UserDefaults.standard.synchronize()
        }

        return mode
    }

    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:countsModeKey)
        UserDefaults.standard.synchronize()
    }
}


var gLineThickness: Double {
    get {
        var value: Double? = UserDefaults.standard.object(forKey: lineThicknessKey) as? Double

        if value == nil {
            value = 1.25

            UserDefaults.standard.set(value, forKey:lineThicknessKey)
            UserDefaults.standard.synchronize()
        }

        return value!
    }

    set {
        UserDefaults.standard.set(newValue, forKey:lineThicknessKey)
        UserDefaults.standard.synchronize()
    }
}


var gInsertionMode: ZInsertionMode {
    get {
        var mode: ZInsertionMode? = nil

        if let object = UserDefaults.standard.object(forKey:insertionModeKey) {
            mode      = ZInsertionMode(rawValue: object as! Int)
        }

        if  mode == nil {
            mode      = .follow

            UserDefaults.standard.set(mode!.rawValue, forKey:insertionModeKey)
            UserDefaults.standard.synchronize()
        }

        return mode!
    }

    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:insertionModeKey)
        UserDefaults.standard.synchronize()
    }
}


var gStorageMode: ZStorageMode {
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

    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:storageModeKey)
        UserDefaults.standard.synchronize()
    }
}


var gSettingsViewIDs: ZSettingsViewID {
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

    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:settingsStateKey)
        UserDefaults.standard.synchronize()
    }
}


// MARK:- user default -- keys and methods
// MARK:-


let     bookmarkColorKey = "bookmark color"
let   backgroundColorKey = "background color"
let  dragTargetsColorKey = "drag targets color"
let insertionModeKey = "graph altering mode"
let       storageModeKey = "current storage mode"
let     settingsStateKey = "current settings state"
let     tinyDotsRatioKey = "tiny dots ratio"
let     lineThicknessKey = "line thickness"
let     genericOffsetKey = "generic offset"
let      scrollOffsetKey = "scroll offset"
let        countsModeKey = "counts mode"


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
