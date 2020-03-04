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
    case idPreferences
    case idFavorites
	case idShortcuts
    case idDetails
    case idActions
	case idStatus
    case idSearch
	case idCrumbs
    case idGraph
	case idDebug
    case idTools
	case idNote
    case idHelp
	case idMain
	case idRing
}

enum ZSignalKind: Int {
    case eData
    case eMain
	case eRing
	case eSwap
    case eDatum
    case eDebug
    case eError
    case eFound
	case eGraph
	case eStatus
	case eResize
	case eSearch
	case eCrumbs
	case eStartup
    case eDetails
    case eRelayout
    case eFavorites
	case eLaunchDone
    case eAppearance
    case ePreferences
}

let gControllers = ZControllers()

class ZControllers: NSObject {

	var priorWorkMode: ZWorkMode?
	var currentController: ZGenericController?
    var signalObjectsByControllerID = [ZControllerID : ZSignalObject] ()

	// MARK:- startup
	// MARK:-

	func startupCloudAndUI() {
		gBatches.usingDebugTimer = true
		gRefusesFirstResponder   = true			// WORKAROUND new feature of mac os x

		gRemoteStorage.clear()
		self.redrawGraph()

		gBatches.startUp { iSame in
			FOREGROUND {
				gIsReadyToShowUI = true

				gFocusRing.push()
				gHereMaybe?.grab()
				gFavorites.updateAllFavorites()
				gRemoteStorage.updateLastSyncDates()
				gRemoteStorage.recount()
				gEssayRing.fetchRingIDs()
				gRefreshCurrentEssay()
				gRefreshPersistentWorkMode()
				self.signalMultiple([.eSwap, .eRelayout, .eLaunchDone])
				self.requestFeedback()

				gBatches.finishUp { iSame in
					FOREGROUND {
						gBatches.usingDebugTimer = false
						gRefusesFirstResponder   = false
						gHasFinishedStartup      = true

						self.signalMultiple([.eRing, .eCrumbs, .eRelayout])
//						self.blankScreenDebug()
//						gFiles.writeAll()
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
								  "Thank you for downloading Thoughtful. Might you be interested in helping me beta test it, giving me feedback about it (good and bad)? \n\nYou can let me know at any time, by selecting Report an Issue under the Help menu (red arrow in image), or now, by clicking the Reply button below.",
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

	// MARK:- hide / reveal
	// MARK:-

	func swapModes() {
		let      last = priorWorkMode ??        .graphMode
		priorWorkMode = gIsSearchMode ? nil  :   gWorkMode
		gWorkMode     = gIsSearchMode ? last : .searchMode
	}

	func showSearch(_ OPTION: Bool = false) {
		if  gDatabaseID  != .favoritesID {
			swapModes()
			signalMultiple([OPTION ? .eFound : .eSearch])
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

	func showHideTooltips() {
		gToolTipsAlwaysVisible = !gToolTipsAlwaysVisible

		signalMultiple([.eRing])
	}

	func showHideRing() {
		gFullRingIsVisible = !gFullRingIsVisible

		signalMultiple([.eRing])
	}

	func showEssay(forGuide: Bool) {
		let recordName = forGuide ? "75F7C2D3-4493-4E30-80D8-2F1F60DA7069" : "96689264-EB25-49CC-9324-913BA5CEBD56"

		if  let    e = gEssayView,
			let zone = gRemoteStorage.maybeZoneForRecordName(recordName) {
			e.resetCurrentEssay(zone.note)
			swapGraphAndEssay(force: .noteMode)
			signalMultiple([.eCrumbs, .eRing])
		}
	}

	func swapGraphAndEssay(force mode: ZWorkMode? = nil) {
		let newMode    			        = mode ?? (gIsNoteMode ? .graphMode : .noteMode)

		if  newMode != gWorkMode {
			gWorkMode 					= newMode
			let showNote 			    = newMode == .noteMode
			let multiple: [ZSignalKind] = [.eSwap, (showNote ? .eCrumbs : .eRelayout)]

			FOREGROUND { 	// avoid infinite recursion (generic menu handler invoking graph editor's handle key)
				gTextEditor.stopCurrentEdit()
				gEssayView?.updateControlBarButtons(showNote)
				self.signalFor(nil, multiple: multiple)
			}
		}
	}

	// MARK:- registry
	// MARK:-

	func controllerForID(_ iID: ZControllerID?) -> ZGenericController? {
		if  let identifier = iID,
			let     object = signalObjectsByControllerID[identifier] {
			return  object.controller
		}

		return nil
	}

	func setSignalHandler(for iController: ZGenericController, iID: ZControllerID, closure: @escaping SignalClosure) {
        signalObjectsByControllerID[iID] = ZSignalObject(closure, forController: iController)
        currentController                = iController
    }

	func clearSignalHandler(_ iID: ZControllerID) {
        signalObjectsByControllerID[iID] = nil
    }

	func backgroundColorFor(_ iID: ZControllerID?) -> ZColor {
		if  let id = iID {
			switch id {
				case .idNote:  return .white
				case .idDetails,
					 .idGraph,
					 .idRing:  return kClearColor
				case .idStatus,
					 .idPreferences,
					 .idTools,
					 .idDebug: return gDarkishBackgroundColor
				default:       return gBackgroundColor
			}
		}

		return gBackgroundColor
	}

	// MARK:- signals
    // MARK:-

	class ZSignalObject {
		let    closure : SignalClosure!
		let controller : ZGenericController!

		init(_ iClosure: @escaping SignalClosure, forController iController: ZGenericController) {
			controller = iController
			closure    = iClosure
		}
	}

	func signalFor(_ object: Any?, regarding: ZSignalKind, onCompletion: Closure? = nil) {
        signalFor(object, multiple: [regarding], onCompletion: onCompletion)
    }

	func signalFor(_ object: Any?, multiple: [ZSignalKind], onCompletion: Closure? = nil) {
        FOREGROUND(canBeDirect: true) {
            gRemoteStorage.updateNeededCounts() // clean up after adding or removing children
            
            for (identifier, signalObject) in self.signalObjectsByControllerID {
                let isPreferences = identifier == .idPreferences
				let      isStatus = identifier == .idStatus
				let      isCrumbs = identifier == .idCrumbs
                let       isDebug = identifier == .idDebug
                let       isGraph = identifier == .idGraph
				let        isRing = identifier == .idRing
                let        isMain = identifier == .idMain
                let      isDetail = isPreferences || isStatus || isDebug
                
                for regarding in multiple {
                    let closure = {
                        signalObject.closure(object, regarding)
                    }
                    
                    switch regarding {
					case .eMain:        if isMain        { closure() }
					case .eRing:        if isRing        { closure() }
                    case .eGraph:       if isGraph       { closure() }
                    case .eDebug:       if isDebug       { closure() }
					case .eStatus:      if isStatus      { closure() }
					case .eCrumbs:      if isCrumbs      { closure() }
                    case .eDetails:     if isDetail      { closure() }
                    case .ePreferences: if isPreferences { closure() }
                    default:                               closure()
                    }
                }
            }

            onCompletion?()
        }
    }

	func sync(onCompletion: Closure? = nil) {
		gBatches.sync() { iSame in
            onCompletion?()
        }
    }

	func signalAndSync(_ zone: Zone?, regarding: ZSignalKind,  onCompletion: Closure?) {
        signalFor(zone, regarding: regarding, onCompletion: nil)
        sync(onCompletion: onCompletion)
    }

}
