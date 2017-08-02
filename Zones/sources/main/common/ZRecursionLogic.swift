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
    case expand     // controlled by expose children, level, count
    case restore    // controlled by expose children
    case inclusive  // fetch deleted, too
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
            let reveal =  iChild.showChildren && (iChild.count == 0 && iChild.hasMissingChildren)
            let expand =  reveal && targetLevel != nil && (targetLevel! < 0 || targetLevel! > iChild.level)

            switch course {
            case .expand:          if expand { iChild.needChildren() }
            case .restore:         if reveal { iChild.needChildren() }
            case .all, .inclusive: propagateDeeply(to: iChild)
            }
        } else if iChild.showChildren, let progenyNeeded = iProgenyNeeded, progenyNeeded.count > 0, let parentReference = iChild.parent, progenyNeeded.contains(parentReference) {
            iChild.needProgeny()
        }
    }

}
