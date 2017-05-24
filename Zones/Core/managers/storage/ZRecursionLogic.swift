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
    case expand     // controlled by expose children, level
    case restore    // controlled by expose children
}


// for each zone, determine whether or not to recurse, AND if so,
// whether or not to add it [in next fetch operation] to references



class ZRecursionLogic: NSObject {


    var targetLevel: Int?
    var type: ZRecursionType?


    init(_ iType: ZRecursionType = .restore, _ iLevel: Int? = nil) {
        super.init()

        self.targetLevel = iLevel
        self       .type = iType
    }


    func applyChildLogic(to iZone: Zone, _ iReferences: [CKReference]?) {
        if iZone.exposeChildren, let references = iReferences, references.count > 0, let parentRef = iZone.parent, references.contains(parentRef) {
            iZone.needProgeny()
        } else if type != nil {
            switch type! {
            case .deep:                               iZone.needProgeny()
            case .update:  if !iZone.isUpToDate     { iZone.needProgeny() }
            case .restore: if  iZone.exposeChildren { iZone.needChildren() }
            default:
                if targetLevel != nil && iZone.exposeChildren && (iZone.count == 0 || iZone.count != iZone.fetchableChildren) && (targetLevel! < 0 || targetLevel! > iZone.level) {
                    iZone.needChildren()
                }
            }
        }
    }

}
