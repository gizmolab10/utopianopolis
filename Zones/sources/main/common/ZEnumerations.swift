//
//  ZEnumerations.swift
//  Zones
//
//  Created by Jonathan Sand on 1/31/18.
//  Copyright © 2018 Zones. All rights reserved.
//


enum ZCloudAccountStatus: Int {
    case none
    case begin
    case available
    case active
}


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
    // case essayMode
    // case outlineMosw
}


enum ZCountsMode: Int { // do not change the order, they are persisted
    case none
    case dots
    case fetchable
    case progeny
}


enum ZDatabaseID: String {
    case favoritesID = "favorites"
    case  everyoneID = "everyone"
    case    sharedID = "shared"
    case      mineID = "mine"
}


enum ZDatabaseIndex: Int {
    case everyone
    case mine
}


func index(of databaseID: ZDatabaseID) -> Int? {
    return databaseIndex(from: databaseID)?.rawValue
}


func databaseIndex(from iID: ZDatabaseID) -> ZDatabaseIndex? {
    switch iID {
    case .everyoneID: return .everyone
    case     .mineID: return .mine
    default:          return nil
    }
}


func databaseIDFrom(_ index: ZDatabaseIndex) -> ZDatabaseID? {
    switch index {
    case .everyone: return .everyoneID
    case .mine:     return .mineID
    }
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


enum ZStorageType: String {
    case found      = "lostAndFound"    // general
    case bookmarks  = "bookmarks"
    case favorites  = "favorites"
    case userID     = "user ID"
    case graph      = "graph"
    case trash      = "trash"
    case date       = "date"

    case recordName = "recordName"      // zones
    case parentLink = "parentLink"
    case attributes = "attributes"
    case children   = "children"
    case progeny    = "progeny"
    case traits     = "traits"
    case access     = "access"
    case owner      = "owner"
    case order      = "order"
    case color      = "color"
    case count      = "count"
    case needs      = "needs"
    case link       = "link"
    case name       = "name"

    case asset      = "asset"           // traits
    case time       = "time"
    case text       = "text"
    case data       = "data"
    case type       = "type"
}

