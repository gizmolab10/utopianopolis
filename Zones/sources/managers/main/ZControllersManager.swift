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
    case shortcuts
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
    case preferences
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


    // MARK:- startup
    // MARK:-
    

    func startupDataAndUI() {
        signalFor(nil, regarding: .startup)
        displayActivity(true)
        gOperationsManager.startUp {
            self.displayActivity(false) // now on foreground thread
            gHere.grab()
            gFavoritesManager.update()
            self.signalFor(nil, regarding: .redraw)
            gOperationsManager.finishUp {
                self.signalFor(nil, regarding: .redraw)
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
        FOREGROUND {
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


    func syncToCloudAndSignalFor(_ zone: Zone?, regarding: ZSignalKind,  onCompletion: Closure?) {
        signalFor(zone, regarding: regarding, onCompletion: onCompletion)

        gOperationsManager.sync {
            onCompletion?()
            gFileManager.save(to: zone?.storageMode)
        }
    }
}
