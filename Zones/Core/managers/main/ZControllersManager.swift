//
//  ZControllersManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/11/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation


enum ZControllerID: Int {
    case undefined
    case searchResults
    case information
    case preferences
    case cloudTools
    case favorites
    case searchBox
    case settings
    case editor
    case help
    case main
}


enum ZSignalKind: Int {
    case data
    case datum
    case error
    case found
    case search
    case redraw
    case startup
}


class ZControllersManager: NSObject {


    var signalObjectsByControllerID = [ZControllerID : ZSignalObject] ()


    class ZSignalObject {
        let    closure: ModeAndSignalClosure!
        let controller: ZGenericController!

        init(_ iClosure: @escaping ModeAndSignalClosure, forController iController: ZGenericController) {
            controller = iController
            closure    = iClosure
        }
    }


    func controllerForID(_ iID: ZControllerID) -> ZGenericController? {
        if let object = signalObjectsByControllerID[iID] {
            return object.controller
        }

        return nil
    }


    // MARK:- registry
    // MARK:-


    func register(_ iController: ZGenericController, iID: ZControllerID, closure: @escaping ModeAndSignalClosure) {
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
        let mode = gStorageMode

        dispatchAsyncInForeground {
            for signalObject: ZSignalObject in self.signalObjectsByControllerID.values {
                signalObject.closure(object, mode, regarding)
            }

            if onCompletion != nil {
                onCompletion!()
            }
        }
    }


    func syncToCloudAndSignalFor(_ zone: Zone?, regarding: ZSignalKind,  onCompletion: Closure?) {
        signalFor(zone, regarding: regarding, onCompletion: onCompletion)

        gOperationsManager.sync {
            onCompletion?()
            gfileManager.save()
        }
    }
}
