//
//  ZControllersManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/11/16.
//  Copyright © 2016 Zones. All rights reserved.
//

import Foundation


class ZControllersManager: NSObject {


    class SignalObject {
        let closure: SignalClosure!

        init(iClosure: @escaping SignalClosure) {
            closure = iClosure
        }
    }


    var       closures: [SignalObject]                    = []
    var controllersMap: [ZControllerID : ZGenericViewController] = [:]


    func register(_ forController: ZGenericViewController, at: ZControllerID) {
        controllersMap[at] = forController
    }


    func controller(at: ZControllerID) -> ZGenericViewController {
        return controllersMap[at]!
    }


    // MARK:- closures
    // MARK:-


    func registerSignal(_ closure: @escaping SignalClosure) {
        closures.append(SignalObject(iClosure: closure))
    }


    func signal(_ object: Any?, regarding: ZUpdateKind, onCompletion: Closure?) {
        dispatchAsyncInForeground {
            for closureObject: SignalObject in self.closures {
                closureObject.closure(object, regarding)
            }

            if onCompletion != nil {
                onCompletion!()
            }
        }
    }


    func signal(_ object: NSObject?, regarding: ZUpdateKind) {
        signal(object, regarding: regarding, onCompletion: nil)
    }


    func saveAndUpdateFor(_ zone: Zone?, onCompletion: Closure?) {
        signal(zone, regarding: .data, onCompletion: onCompletion)
        zfileManager.save()
        cloudManager.flushOnCompletion {}
    }


    func saveAndUpdateFor(_ zone: Zone?) {
        saveAndUpdateFor(zone, onCompletion: nil)
    }
}
