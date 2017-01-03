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


enum ZEditMode: Int {
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
    static let     Details = ZSettingsState(rawValue: 1 << 2)
    static let     Actions = ZSettingsState(rawValue: 1 << 3)
    static let         All = ZSettingsState(rawValue: 0xFFFF)
}


var recursivelyExpand = false
var    showsSearching = false
var     textCapturing = false
var          editMode = ZEditMode.task
var          fileMode = ZFileMode.cloud
var          workMode = ZWorkMode.editMode
var     genericOffset = CGSize(width: 0.0, height: 4.0)
var         lineColor = ZColor.purple //(hue: 0.6, saturation: 0.6, brightness: 1.0,                alpha: 1)
var     bookmarkColor = ZColor.blue
var   unselectedColor = ZColor(hue: 0.6, saturation: 0.0, brightness: unselectBrightness, alpha: 1)
var      lineThicknes = 1.25
var         dotHeight = 12.0


var               asTask:   Bool { get { return editMode == .task             } }
var grabbedBookmarkColor: ZColor { get { return bookmarkColor.darker(by: 1.5) } }
var     grabbedTextColor: ZColor { get { return lineColor    .darker(by: 1.8) } }


var gStorageMode: ZStorageMode {
    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:storageModeKey)
    }

    get {
        var mode: ZStorageMode? = nil

        if let object = UserDefaults.standard.object(forKey:storageModeKey) {
            mode      = ZStorageMode(rawValue: object as! String)
        }

        if mode == nil {
            mode      = .everyone

            UserDefaults.standard.set(mode!.rawValue, forKey:storageModeKey)
        }

        return mode!
    }
}


var settingsState: ZSettingsState {
    set {
        UserDefaults.standard.set(newValue.rawValue, forKey:settingsStateKey)
    }

    get {
        var state: ZSettingsState? = nil

        if let object = UserDefaults.standard.object(forKey:settingsStateKey) {
            state     = ZSettingsState(rawValue: object as! Int)
        }

        if state == nil {
            state     = .All

            UserDefaults.standard.set(state!.rawValue, forKey:settingsStateKey)
        }

        return state!
    }
}
