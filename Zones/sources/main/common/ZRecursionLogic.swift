//
//  ZRecursionLogic.swift
//  Zones
//
//  Created by Jonathan Sand on 5/23/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import CloudKit


enum ZRecursionType: Int {
    case all        // always recurse
    case update     // controlled by is up to date
    case expand     // controlled by expose children, level, count
    case restore    // controlled by expose children
}


// for each zone, determine whether or not to recurse, AND if so,
// whether or not to extensively recurse [add to references, in next fetch operation)


class ZRecursionLogic: NSObject {


    var        type: ZRecursionType?
    var targetLevel: Int?


    init(_ iType: ZRecursionType = .restore, _ iLevel: Int? = nil) {
        super.init()

        self.targetLevel = iLevel
        self       .type = iType
    }


    func propagateDeeply(to iChild: Zone) {
        iChild.traverseAllProgeny { iZone in
            if iZone.hasMissingChildren {
                iZone.needProgeny()
            }
        }
    }


    func propagateNeeds(to iChild: Zone, _ iProgenyNeeded: [CKReference]?) {
        if  let course =  type {
            let update = !iChild.isUpToDate
            let reveal =  iChild.showChildren && (iChild.count == 0 && iChild.hasMissingChildren)
            let expand =  reveal && targetLevel != nil && (targetLevel! < 0 || targetLevel! > iChild.level)

            switch course {
            case .expand:  if expand { iChild.needChildren() }
            case .restore: if reveal { iChild.needChildren() }
            case .update:  if update { iChild.needProgeny() }
            case .all:                 propagateDeeply(to: iChild)
            }
        } else if iChild.showChildren, let progenyNeeded = iProgenyNeeded, progenyNeeded.count > 0, let parentReference = iChild.parent, progenyNeeded.contains(parentReference) {
            iChild.needProgeny()
        }
    }

}
