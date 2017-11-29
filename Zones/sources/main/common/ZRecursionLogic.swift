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
    case color      // only used by fetch parents
    case expand     // controlled by show children, level, count
    case restore    // controlled by show children
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
            if  iZone.hasMissingChildren {
                iZone.needProgeny()
            }
        }
    }


    func propagateNeeds(to iChild: Zone, _ iProgenyNeeded: [CKReference]?) {
        let        reveal = iChild.showChildren && iChild.hasMissingChildren
        if  let recursing = type, recursing != .all {
            let    expand = reveal && targetLevel != nil && (targetLevel! < 0 || targetLevel! > iChild.level)

            switch recursing {
            case .expand:  if expand { iChild.needChildren() }
            case .restore: if reveal { iChild.needChildren() }
            default:       break
            }
        } else if reveal,
            let parentReference = iChild.parent,
            let   progenyNeeded = iProgenyNeeded,
            progenyNeeded.count > 0,
            progenyNeeded.contains(parentReference) {
            iChild.needProgeny()
        }
    }

}
