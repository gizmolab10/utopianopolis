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
    case deep       // always recurse
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
        iChild.traverseAll() { iZone in
            if iZone.count != iZone.fetchableCount {
                iZone.needProgeny()
            }
        }
    }


    func propagateNeeds(to iChild: Zone, _ iProgenyNeeded: [CKReference]?) {
        if type != nil {
            let    update = !iChild.isUpToDate
            let unfetched =  iChild.count != iChild.fetchableCount
            let    reveal =  iChild.canRevealChildren && (iChild.count == 0 || unfetched)
            let    expand =  reveal && targetLevel != nil && (targetLevel! < 0 || targetLevel! > iChild.level)

            switch type! {
            case .expand:  if expand { iChild.needChildren() }
            case .restore: if reveal { iChild.needChildren() }
            case .update:  if update { iChild.needProgeny() }
            case .deep:                propagateDeeply(to: iChild)
            }
        } else if iChild.canRevealChildren, let parentRef = iChild.parent, let progenyNeeded = iProgenyNeeded, progenyNeeded.count > 0, progenyNeeded.contains(parentRef) {
            iChild.needProgeny()
        }
    }

}
