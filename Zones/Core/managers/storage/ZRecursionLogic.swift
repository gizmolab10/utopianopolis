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


    func updateNeeds(for iChild: Zone, _ iProgenyNeeded: [CKReference]?) {
        if iChild.exposeChildren, let progenyNeeded = iProgenyNeeded, progenyNeeded.count > 0, let parentRef = iChild.parent, progenyNeeded.contains(parentRef) {
            iChild.needProgeny()
        } else if type != nil {
            let updated = iChild.isUpToDate
            let  expose = iChild.exposeChildren
            let  expand = targetLevel != nil && expose && (iChild.count == 0 || iChild.count != iChild.fetchableChildren) && (targetLevel! < 0 || targetLevel! > iChild.level)

            switch type! {
            case .expand:  if   expand { iChild.needChildren() }
            case .restore: if   expose { iChild.needChildren() }
            case .update:  if !updated { iChild.needProgeny()  }
            case .deep:                  iChild.needProgeny()
            }
        }
    }

}
