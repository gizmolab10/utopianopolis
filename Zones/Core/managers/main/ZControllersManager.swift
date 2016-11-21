//
//  ZControllersManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/11/16.
//  Copyright © 2016 Zones. All rights reserved.
//

import Foundation


class ZControllersManager: NSObject {


    class UpdateClosureObject {
        let closure: UpdateClosure!

        init(iClosure: @escaping UpdateClosure) {
            closure = iClosure
        }
    }


    var       closures: [UpdateClosureObject]                    = []
    var controllersMap: [ZControllerID : ZGenericViewController] = [:]


    func register(_ forController: ZGenericViewController, at: ZControllerID) {
        controllersMap[at] = forController
    }


    func controller(at: ZControllerID) -> ZGenericViewController {
        return controllersMap[at]!
    }


    // MARK:- closures
    // MARK:-


    func registerUpdateClosure(_ closure: @escaping UpdateClosure) {
        closures.append(UpdateClosureObject(iClosure: closure))
    }


    func updateToClosures(_ object: Any?, regarding: ZUpdateKind, onCompletion: Closure?) {
        let closure = {
            for closureObject: UpdateClosureObject in self.closures {
                closureObject.closure(object, regarding)
            }

            if onCompletion != nil {
                onCompletion!()
            }
        }

        if Thread.isMainThread {
            closure()
        } else {
            DispatchQueue.main.async { closure() }
        }
    }


    func updateToClosures(_ object: NSObject?, regarding: ZUpdateKind) {
        updateToClosures(object, regarding: regarding, onCompletion: nil)
    }


    func saveAndUpdateFor(_ zone: Zone?, onCompletion: Closure?) {
        updateToClosures(zone, regarding: .data, onCompletion: onCompletion)
        zfileManager.save()
        cloudManager.flushOnCompletion {}
    }


    func saveAndUpdateFor(_ zone: Zone?) {
        saveAndUpdateFor(zone, onCompletion: nil)
    }
}
