//
//  ZControllersManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/11/16.
//  Copyright © 2016 Zones. All rights reserved.
//

import Foundation


enum ZControllerID: Int {
    case editor
    case tools
    case main
}


enum ZSignalKind: Int {
    case data
    case datum
    case error
    case delete
}


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


    func displayActivity() {
        dispatchAsyncInForeground {
            for controller in self.controllersMap.values {
                controller.displayActivity()
            }
        }
    }


    func signal(_ object: Any?, regarding: ZSignalKind, onCompletion: Closure?) {
        dispatchAsyncInForeground {
            for closureObject: SignalObject in self.closures {
                closureObject.closure(object, regarding)
            }

            if onCompletion != nil {
                onCompletion!()
            }
        }
    }


    func signal(_ object: NSObject?, regarding: ZSignalKind) {
        signal(object, regarding: regarding, onCompletion: nil)
    }


    func saveAndUpdateFor(_ zone: Zone?, onCompletion: Closure?) {
        signal(zone, regarding: .data, onCompletion: onCompletion)

        operationsManager.sync {
            self.signal(zone, regarding: .data, onCompletion: onCompletion)
            zfileManager.save()
        }
    }


    func saveAndUpdateFor(_ zone: Zone?) {
        saveAndUpdateFor(zone, onCompletion: nil)
    }
}
