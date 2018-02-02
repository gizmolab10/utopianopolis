//
//  ZEnumerations.swift
//  Zones
//
//  Created by Jonathan Sand on 1/31/18.
//  Copyright © 2018 Zones. All rights reserved.
//


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
    static let   Shortcuts = ZDetailsViewID(rawValue: 1 << 2)
    static let       Tools = ZDetailsViewID(rawValue: 1 << 3)
    static let       Debug = ZDetailsViewID(rawValue: 1 << 4)
    static let         All = ZDetailsViewID(rawValue: 0xFFFF)
}

