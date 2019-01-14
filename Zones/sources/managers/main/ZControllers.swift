//
//  ZControllers.swift
//  Thoughtful
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
    case shortcuts
    case details
    case actions
    case editor
    case search
    case debug
    case tools
    case help
    case main
}


enum ZSignalKind: Int {
    case eData
    case eMain
    case eDatum
    case eDebug
    case eError
    case eFound
    case eSearch
    case eStartup
    case eDetails
    case eRelayout
    case eFavorites
    case eAppearance
    case eInformation
    case ePreferences
}


let gControllers = ZControllers()


class ZControllers: NSObject {


    var currentController: ZGenericController?
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


    // MARK:- startup
    // MARK:-


    func startupCloudAndUI() {
        gBatches.usingDebugTimer = true

        gRemoteStorage.clear()
        self.signalFor(nil, regarding: .eRelayout)

        gBatches.startUp { iSame in
            FOREGROUND {
                gWorkMode        = .graphMode
                gIsReadyToShowUI = true

                gHere.grab()
                gFavorites.updateAllFavorites()
                gRemoteStorage.updateLastSyncDates()
                gRemoteStorage.recount()
                self.signalFor(nil, regarding: .eRelayout)
                self.requestFeedback()
                
                gBatches.finishUp { iSame in
                    FOREGROUND {
                        gBatches.usingDebugTimer = false

                        self.blankScreenDebug()
                        gFiles.writeAll()
                    }
                }
            }
        }
    }

    
    func requestFeedback() {
        if       !emailSent(for: .eBetaTesting) {
            recordEmailSent(for: .eBetaTesting)

            FOREGROUND(after: 0.1) {
                let image = ZImage(named: kHelpMenuImageName)
                
                gAlerts.showAlert("Please forgive my interruption",
                                        "Thank you for downloading Thoughtful. You are one of my first customers. \n\nMy other product (no longer available) received 99% positive customer satisfaction. Receiving the same for Thoughtful would mean a lot to me, of course. I built Thoughtful alone so far, but it's getting hefty. Might you be interested in helping me beta test Thoughtful, giving me feedback about it (good and bad)? \n\nYou can let me know at any time, by selecting Report an Issue under the Help menu (red arrow), or now, by clicking the Reply button below.",
                                        "Reply in an email",
                                        "Dismiss",
                                        image) { iObject in
                                            if  iObject != .eStatusNo {
                                                self.sendEmailBugReport()
                                            }
                }
            }
        }
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
        for cloud in gRemoteStorage.allClouds {
            var alsoProgenyCounts = false
            cloud.fullUpdate(for: [.needsCount]) { state, iZRecord in
                if  let zone                 = iZRecord as? Zone {
                    if  zone.fetchableCount != zone.count {
                        zone.fetchableCount  = zone.count
                        alsoProgenyCounts    = true

                        zone.maybeNeedSave()
                    }
                }
            }

            if  alsoProgenyCounts {
                cloud.rootZone?.updateCounts()
            }
        }
    }


    func signalFor(_ object: Any?, regarding: ZSignalKind, onCompletion: Closure? = nil) {
        FOREGROUND(canBeDirect: true) {
            self.updateNeededCounts() // clean up after adding or removing children
            
            for (identifier, signalObject) in self.signalObjectsByControllerID {
                let isInformation = identifier == .information
                let isPreferences = identifier == .preferences
                let       isDebug = identifier == .debug
                let        isMain = identifier == .main
                let      isDetail = isInformation || isPreferences || isDebug
                
                let closure = {
                    signalObject.closure(object, regarding)                    
                }

                switch regarding {
                case .eMain:        if isMain        { closure() }
                case .eDebug:       if isDebug       { closure() }
                case .eDetails:     if isDetail      { closure() }
                case .eInformation: if isInformation { closure() }
                case .ePreferences: if isPreferences { closure() }
                default:                               closure()
                }
            }

            onCompletion?()
        }
    }
    
    
    func sync(_ zone: Zone?, onCompletion: Closure?) {
        gBatches.sync { iSame in
            onCompletion?()
        }
    }
    
    
    func syncToCloudAfterSignalFor(_ zone: Zone?, regarding: ZSignalKind,  onCompletion: Closure?) {
        signalFor(zone, regarding: regarding, onCompletion: nil)
        sync(zone, onCompletion: onCompletion)
    }
}
