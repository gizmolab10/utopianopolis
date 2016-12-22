//
//  ZControllersManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/11/16.
//  Copyright © 2016 Zones. All rights reserved.
//

import Foundation


enum ZControllerID: Int {
    case searchResults
    case searchBox
    case editor
    case tools
    case main
}


enum ZSignalKind: Int {
    case data
    case datum
    case error
    case found
    case search
}


class ZControllersManager: NSObject {


    class SignalObject {
        let closure: SignalClosure!
        let controller: ZGenericViewController!

        init(_ iClosure: @escaping SignalClosure, forController iController: ZGenericViewController) {
            controller = iController
            closure    = iClosure
        }
    }


    var controllersMap = [ZControllerID : SignalObject] ()


    func unregister(_ at: ZControllerID) {
        controllersMap[at] = nil
    }


    func register(_ iController: ZGenericViewController, at: ZControllerID, closure: @escaping SignalClosure) {
        if !controllersMap.keys.contains(at) {
            controllersMap[at] = SignalObject(closure, forController: iController)
        }
    }


    func controller(at: ZControllerID) -> ZGenericViewController {
        let signalObject = controllersMap[at]!

        return signalObject.controller
    }

    
    func displayActivity() {
        dispatchAsyncInForeground {
            for signalObject in self.controllersMap.values {
                signalObject.controller.displayActivity()
            }
        }
    }


    func signalAboutObject(_ object: Any?, regarding: ZSignalKind, onCompletion: Closure?) {
        dispatchAsyncInForeground {
            for signalObject: SignalObject in self.controllersMap.values {
                signalObject.closure(object, regarding)
            }

            if onCompletion != nil {
                onCompletion!()
            }
        }
    }


    func signalAboutObject(_ object: NSObject?, regarding: ZSignalKind) {
        signalAboutObject(object, regarding: regarding, onCompletion: nil)
    }


    func syncToCloudAndSignalFor(_ zone: Zone?, onCompletion: Closure?) {
        dispatchAsyncInForeground {
            self.signalAboutObject(zone, regarding: .data, onCompletion: onCompletion)

            operationsManager.sync {
                zfileManager.save()
            }
        }
    }


    func syncToCloudAndSignalFor(_ zone: Zone?) {
        syncToCloudAndSignalFor(zone, onCompletion: nil)
    }
}
