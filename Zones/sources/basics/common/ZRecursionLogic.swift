//
//  ZRecursionLogic.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/23/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


enum ZRecursionType: Int {
    case all        // always recurse
    case color      // only used by fetch parents
    case expand     // controlled by show children, level, count
    case restore    // controlled by show children
}


let gRecursionLogic = ZRecursionLogic()


// for each zone, determine whether or not to recurse, AND if so,
// whether or not to extensively recurse [add to references, in next fetch operation)


class ZRecursionLogic: NSObject {


    var        type: ZRecursionType?
    var targetLevel: Int = Int.max


    init(_ iType: ZRecursionType = .all, _ iLevel: Int = Int.max) {
        super.init()

        self.targetLevel = iLevel
        self       .type = iType
    }


    func propagateDeeply(to iChild: Zone) {
        iChild.traverseAllProgeny { iZone in
            if  iZone.hasMissingChildren() {
                iZone.needProgeny()
            }
        }
    }


    func propagateNeeds(to iChild: Zone, _ iProgenyNeeded: [CKRecord.Reference]?) {
        if  let recursing = type, recursing != .all {
            let    reveal = iChild.showingChildren && iChild.hasMissingChildren()
            let    expand = reveal && (targetLevel < 0 || targetLevel > iChild.level)

			switch recursing {
				case .expand:  if expand { iChild.reallyNeedChildren() }
				case .restore: if reveal { iChild.reallyNeedChildren() }
				default:       break
			}
        } else if let progenyNeeded = iProgenyNeeded,
            let     parentReference = iChild.parent,
            progenyNeeded.count    != 0,
            progenyNeeded.contains(parentReference) {
            iChild.reallyNeedProgeny()
        }
    }

}
