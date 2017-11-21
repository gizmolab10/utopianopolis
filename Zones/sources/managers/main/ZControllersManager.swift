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
    case authenticate
    case information
    case preferences
    case cloudTools
    case favorites
    case searchBox
    case shortcuts
    case settings
    case actions
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
    case information
    case preferences
}


let gControllersManager = ZControllersManager()


class ZControllersManager: NSObject {


    var currentController: ZGenericController? = nil
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
        currentController                = iController
    }


    func unregister(_ at: ZControllerID) {
        signalObjectsByControllerID[at] = nil
    }


    // MARK:- startup
    // MARK:-
    

    func startupDataAndUI() {
        gDBOperationsManager.debugTimer = true

        signalFor(nil, regarding: .startup)
        displayActivity(true)
        gRemoteStoresManager.clear()
        gDBOperationsManager.startUp {
            gFavoritesManager.setup() // manifest has been fetched
            gDBOperationsManager.continueUp {
                gWorkMode                       = .editMode
                gDBOperationsManager.debugTimer = false

                if gManifest.alreadyExists {
                    gHere.grab()
                    gFavoritesManager.updateChildren()
                    self.displayActivity(false)
                    self.signalFor(nil, regarding: .redraw)
                }

                gDBOperationsManager.finishUp {}
            }
        }
    }


    // MARK:- signals
    // MARK:-


    func displayActivity(_ show: Bool) {
        FOREGROUND {
            for signalObject in self.signalObjectsByControllerID.values {
                signalObject.controller.displayActivity(show)
            }
        }
    }


    func updateCounts() {
        var alsoProgenyCounts = false

        gCloudManager.fullUpdate() { state, record in
            if  let            zone = record as? Zone {
                zone.fetchableCount = zone.count
                alsoProgenyCounts   = true
            }
        }

        if alsoProgenyCounts {
            gRoot?.safeUpdateProgenyCount([])
        }
    }


    func signalFor(_ object: Any?, regarding: ZSignalKind, onCompletion: Closure?) {
        FOREGROUND(canBeDirect: true) {
            let mode = gStorageMode
            
            self.updateCounts() // clean up after fetch children

            for (identifier, signalObject) in self.signalObjectsByControllerID {
                switch regarding {
                case .preferences: if identifier == .preferences { signalObject.closure(object, mode, regarding) }
                default:                                           signalObject.closure(object, mode, regarding)
                }
            }

            onCompletion?()
        }
    }


    func syncAndSave(_ zone: Zone? = nil, onCompletion: Closure?) {
        gDBOperationsManager.sync {
            onCompletion?()
            gFileManager.save(to: zone?.storageMode)
        }
    }


    func syncToCloudAndSignalFor(_ zone: Zone?, regarding: ZSignalKind,  onCompletion: Closure?) {
        signalFor(zone, regarding: regarding, onCompletion: onCompletion)
        syncAndSave(zone, onCompletion: onCompletion)
    }
}
