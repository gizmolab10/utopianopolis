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


func typefrom(_ keyPath: String) -> ZStorageType? {
    if  let    type = ZStorageType(rawValue: keyPath) {
        return type
    }

    switch keyPath {
    case kRecordName: return .recordName
    case "children":  return .children
    case "traits":    return .traits
    case "parent":    return nil
    default:
        let closure = { (iPrefix: String) -> (ZStorageType?) in
            let           parts = keyPath.components(separatedBy: iPrefix)

            if  parts.count > 1 {
                let      suffix = parts[1].lowercased()

                if  let    type = ZStorageType(rawValue: suffix) {
                    return type
                }
            }

            return nil
        }

        if let type = closure("zone")   { return type }
        if let type = closure("record") { return type }

        return nil
    }
}


enum ZStorageType: String {
    case traits         = "traits"
    case children       = "children"
    case recordName     = "recordName"
    case recordType     = "type"
    case progenyCount   = "progeny"
    case databaseID     = "databaseID"
    case parentLink     = "parentLink"
    case attributes     = "attributes"
    case access         = "access"
    case owner          = "owner"
    case order          = "order"
    case color          = "color"
    case count          = "count"
    case link           = "link"
    case name           = "name"
    case composition    = "composition"
    case hyperlink      = "hyperlink"
    case duration       = "duration"
    case graphic        = "graphic"
    case email          = "email"
    case money          = "money"
    case time           = "time"

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

