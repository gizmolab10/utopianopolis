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


enum ZStorageType: String {
    case properties     = "properties"
    case bookmarks      = "bookmarks"
    case favorites      = "favorites"
    case children       = "children"
    case userID         = "userID"
    case traits         = "traits"
    case graph          = "graph"
    case date           = "date"

    case recordName     = "recordName"
    case parentLink     = "parentLink"
    case attributes     = "attributes"
    case progeny        = "progeny"
    case access         = "access"
    case owner          = "owner"
    case order          = "order"
    case color          = "color"
    case count          = "count"
    case needs          = "needs"
    case link           = "link"
    case name           = "name"

    case asset          = "asset"
    case time           = "time"
    case text           = "text"
    case data           = "data"
    case type           = "type"
}


enum ZCountsMode: Int {
    case none
    case dots
    case fetchable
    case progeny
}


func indexOf(_ iID: ZDatabaseID) -> Int? {
    switch iID {
    case .everyoneID: return 0
    case     .mineID: return 1
    default:          return nil
    }
}


enum ZDatabaseID: String {
    case favoritesID = "favorites"
    case  everyoneID = "everyone"
    case    sharedID = "shared"
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

