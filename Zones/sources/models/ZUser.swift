//
//  ZUser.swift
//  Zones
//
//  Created by Jonathan Sand on 10/26/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import CloudKit


enum ZUserAccess: Int {
    case eAccessNormal
    case eAccessFull
}


class ZUser : ZRecord {


    @objc dynamic var    authorID: String?
    @objc dynamic var writeAccess: NSNumber?


    var access: ZUserAccess {
        get {
            updateInstanceProperties()

            if  writeAccess == nil {
                writeAccess  = NSNumber(value: ZUserAccess.eAccessNormal.rawValue)
            }

            return ZUserAccess(rawValue: writeAccess!.intValue)!
        }

        set {
            if  newValue != access {
                writeAccess = NSNumber(value: newValue.rawValue)
            }
        }
    }

    
    override func cloudProperties() -> [String] {
        return [#keyPath(authorID),
                #keyPath(writeAccess)]
    }


}
