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
    case favorites
    case searchBox
    case shortcuts
    case details
    case actions
    case editor
    case debug
    case tools
    case help
    case main
}


enum ZSignalKind: Int {
    case data
    case datum
    case debug
    case error
    case found
    case search
    case redraw
    case startup
    case details
    case information
    case preferences
}


let gControllersManager = ZControllersManager()


class ZControllersManager: NSObject {


    var currentController: ZGenericController? = nil
    var signalObjectsByControllerID = [ZControllerID : ZSignalObject] ()


    class ZSignalObject {
        let    closure: SignalClosure!
        let controller: ZGenericController!

        init(_ iClosure: @escaping SignalClosure, forController iController: ZGenericController) {
            controller = iController
            closure    = iClosure
        }
    }


    func controllerForID(_ iID: ZControllerID?) -> ZGenericController? {
        if  let identifier = iID,
            let     object = signalObjectsByControllerID[identifier] {
            return object.controller
        }

        return nil
    }


    // MARK:- registry
    // MARK:-


    func register(_ iController: ZGenericController, iID: ZControllerID, closure: @escaping SignalClosure) {
        signalObjectsByControllerID[iID] = ZSignalObject(closure, forController: iController)
        currentController                = iController
    }


    func unregister(_ at: ZControllerID) {
        signalObjectsByControllerID[at] = nil
    }


    // MARK:- startup
    // MARK:-
    

    func startupCloudAndUI() {
        gBatchManager.usingDebugTimer = true

        gRemoteStoresManager.clear()
        displayActivity(true)
        gBatchManager.startUp {
            gFavoritesManager.setup {
                gBatchManager.continueUp {
                    gWorkMode   = .graphMode
                    gReadyState = true

                    self.displayActivity(false)
                    gHere.grab()
                    gFavoritesManager.updateFavorites()
                    self.signalFor(nil, regarding: .redraw)

                    gBatchManager.finishUp {
                        self.blankScreenDebug()
                        gBatchManager.families() { iSame in // created bookmarks and parents of bookmarks
                            gBatchManager.usingDebugTimer = false

                            self.signalFor(nil, regarding: .redraw)
                            gRemoteStoresManager.updateLastSyncDates()
                        }
                    }
                }
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


    func updateNeededCounts() {
        for dbID in gAllDatabaseIDs {
            var alsoProgenyCounts = false
            let           manager = gRemoteStoresManager.cloudManagerFor(dbID)
            manager.fullUpdate(for: [.needsCount]) { state, iZRecord in
                if  let zone                 = iZRecord as? Zone {
                    if  zone.fetchableCount != zone.count {
                        zone.fetchableCount  = zone.count
                        alsoProgenyCounts    = true

                        zone.maybeNeedSave()
                    }
                }
            }

            if  alsoProgenyCounts {
                manager.rootZone?.safeUpdateCounts([])
            }
        }
    }


    func signalFor(_ object: Any?, regarding: ZSignalKind, onCompletion: Closure?) {
        FOREGROUND(canBeDirect: true) {
            self.updateNeededCounts() // clean up after adding or removing children

            for (identifier, signalObject) in self.signalObjectsByControllerID {
                let isInformation = identifier == .information
                let isPreferences = identifier == .preferences
                let       isDebug = identifier == .debug
                let      isDetail = isInformation || isPreferences || isDebug

                switch regarding {
                case .debug:       if isDebug       { signalObject.closure(object, regarding) }
                case .details:     if isDetail      { signalObject.closure(object, regarding) }
                case .information: if isInformation { signalObject.closure(object, regarding) }
                case .preferences: if isPreferences { signalObject.closure(object, regarding) }
                default:                              signalObject.closure(object, regarding)
                }
            }

            onCompletion?()
        }
    }


    func syncAndSave(_ widget: ZoneWidget? = nil, onCompletion: Closure?) {
        gBatchManager.sync { iSame in
            onCompletion?()
        }
    }


    func syncToCloudAndSignalFor(_ widget: ZoneWidget?, regarding: ZSignalKind,  onCompletion: Closure?) {
        signalFor(widget, regarding: regarding, onCompletion: onCompletion)
        syncAndSave(widget, onCompletion: onCompletion)
    }
}
