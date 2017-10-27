//
//  ZUserManager.swift
//  iFocus
//
//  Created by Jonathan Sand on 10/26/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZUserManager : NSObject {

    
    var isSpecialUser: Bool { return false }


    func userCanAlter(_ zone: Zone) -> Bool {
        return isSpecialUser

        /////////////////////////////////
        // or is owned by current user //
        /////////////////////////////////

    }
}
