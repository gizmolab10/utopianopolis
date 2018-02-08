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
    case localOnly
    case cloudOnly
    case all
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


func indexOf(_ iID: ZDatabaseiD) -> Int? {
    switch iID {
    case .everyoneID: return 0
    case     .mineID: return 1
    default:          return nil
    }
}


enum ZDatabaseiD: String {
    case favoritesID = "favorites"
    case  everyoneID = "everyone"
    case    sharedID = "group"
    case      mineID = "mine"
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

