//
//  ZControllers.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 11/11/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation

enum ZControllerID: Int {
    case idUndefined
    case idSearchResults
    case idAuthenticate
    case idInformation
    case idPreferences
    case idFavorites
	case idShortcuts
    case idDetails
    case idActions
    case idSearch
    case idGraph
    case idDebug
	case idEssay
    case idTools
    case idHelp
    case idMain
}

enum ZSignalKind: Int {
    case eData
    case eMain
    case eDatum
    case eDebug
    case eError
    case eFound
	case eGraph
	case eEssay
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
        let    closure : SignalClosure!
        let controller : ZGenericController!

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

	// MARK:- hide / reveal
	// MARK:-

	func swapGraphAndEssay() {
		FOREGROUND { 	// avoid generic menu handler invoking graph editor's handle key
			let showEssay 				= gWorkMode == .graphMode
			let multiple: [ZSignalKind] = showEssay ? [.eEssay] : [.eEssay, .eRelayout]
			gWorkMode     				= showEssay ? .essayMode : .graphMode

			gTextEditor.stopCurrentEdit()
			gEssayView?.updateButtons(showEssay)
			self.signalFor(gSelecting.firstGrab, multiple: multiple)
		}
	}

	func showShortcuts(_ show: Bool? = nil) {
		if  let shorts = gShortcutsController {
			if  show ?? !(shorts.window?.isKeyWindow ?? false) {
				shorts.showWindow(nil)
			} else {
				shorts.window?.close()
			}
		}
	}

    // MARK:- startup
    // MARK:-

	func startupCloudAndUI() {
        gBatches         .usingDebugTimer = true
		gTextEditor.refusesFirstResponder = true			// WORKAROUND new feature of mac os x

        gRemoteStorage.clear()
        self.signalFor(nil, regarding: .eRelayout)

        gBatches.startUp { iSame in
            FOREGROUND {
                gWorkMode        = .graphMode
                gIsReadyToShowUI = true

                gHereMaybe?.grab()
                gFavorites.updateAllFavorites()
                gRemoteStorage.updateLastSyncDates()
                gRemoteStorage.recount()
                self.signalFor(nil, regarding: .eRelayout)
                self.requestFeedback()
                
                gBatches.finishUp { iSame in
                    FOREGROUND {
                        gBatches		 .usingDebugTimer = false
						gTextEditor.refusesFirstResponder = false
						gHasCompletedStartup              = true

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

	func setSignalHandler(for iController: ZGenericController, iID: ZControllerID, closure: @escaping SignalClosure) {
        signalObjectsByControllerID[iID] = ZSignalObject(closure, forController: iController)
        currentController                = iController
    }

	func clearSignalHandler(_ iID: ZControllerID) {
        signalObjectsByControllerID[iID] = nil
    }

	// MARK:- signals
    // MARK:-

	func signalFor(_ object: Any?, regarding: ZSignalKind, onCompletion: Closure? = nil) {
        signalFor(object, multiple: [regarding], onCompletion: onCompletion)
    }

	func signalFor(_ object: Any?, multiple: [ZSignalKind], onCompletion: Closure? = nil) {
        FOREGROUND(canBeDirect: true) {
            gRemoteStorage.updateNeededCounts() // clean up after adding or removing children
            
            for (identifier, signalObject) in self.signalObjectsByControllerID {
                let isInformation = identifier == .idInformation
                let isPreferences = identifier == .idPreferences
                let       isDebug = identifier == .idDebug
                let       isGraph = identifier == .idGraph
                let        isMain = identifier == .idMain
                let      isDetail = isInformation || isPreferences || isDebug
                
                for regarding in multiple {
                    let closure = {
                        signalObject.closure(object, regarding)
                    }
                    
                    switch regarding {
                    case .eMain:        if isMain        { closure() }
                    case .eGraph:       if isGraph       { closure() }
                    case .eDebug:       if isDebug       { closure() }
                    case .eDetails:     if isDetail      { closure() }
                    case .eInformation: if isInformation { closure() }
                    case .ePreferences: if isPreferences { closure() }
                    default:                               closure()
                    }
                }
            }

            onCompletion?()
        }
    }

	func sync(onCompletion: Closure? = nil) {
        gBatches.sync { iSame in
            onCompletion?()
        }
    }

	func syncToCloudAfterSignalFor(_ zone: Zone?, regarding: ZSignalKind,  onCompletion: Closure?) {
        signalFor(zone, regarding: regarding, onCompletion: nil)
        sync(onCompletion: onCompletion)
    }

}
