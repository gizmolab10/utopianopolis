//
//  ZControllersManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/11/16.
//  Copyright © 2016 Zones. All rights reserved.
//

import Foundation


enum ZControllerID: Int {
    case undefined
    case searchResults
    case searchBox
    case settings
    case editor
    case main
}


enum ZSignalKind: Int {
    case data
    case datum
    case error
    case found
    case search
    case redraw
}


class ZControllersManager: NSObject {


    var signalObjectsByControllerID = [ZControllerID : ZSignalObject] ()


    class ZSignalObject {
        let    closure: SignalClosure!
        let controller: ZGenericViewController!

        init(_ iClosure: @escaping SignalClosure, forController iController: ZGenericViewController) {
            controller = iController
            closure    = iClosure
        }
    }


    func controllerForID(_ iID: ZControllerID) -> ZGenericViewController? {
        if let object = signalObjectsByControllerID[iID] {
            return object.controller
        }

        return nil
    }


    // MARK:- registry
    // MARK:-


    func register(_ iController: ZGenericViewController, iID: ZControllerID, closure: @escaping SignalClosure) {
        signalObjectsByControllerID[iID] = ZSignalObject(closure, forController: iController)
    }


    func unregister(_ at: ZControllerID) {
        signalObjectsByControllerID[at] = nil
    }


    // MARK:- signals
    // MARK:-


    func displayActivity() {
        dispatchAsyncInForeground {
            for signalObject in self.signalObjectsByControllerID.values {
                signalObject.controller.displayActivity()
            }
        }
    }


    func signalFor(_ object: Any?, regarding: ZSignalKind, onCompletion: Closure?) {
        dispatchAsyncInForeground {
            for signalObject: ZSignalObject in self.signalObjectsByControllerID.values {
                signalObject.closure(object, regarding)
            }

            if onCompletion != nil {
                onCompletion!()
            }
        }
    }


    func syncToCloudAndSignalFor(_ zone: Zone?, regarding: ZSignalKind,  onCompletion: Closure?) {
        signalFor             (zone, regarding: regarding, onCompletion: onCompletion)
        dispatchAsyncInForeground {
            gOperationsManager.sync {
                onCompletion?()
                gfileManager.save()
            }
        }
    }
}
