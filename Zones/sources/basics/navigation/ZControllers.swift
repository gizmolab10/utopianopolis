//
//  ZControllers.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/11/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation

enum ZControllerID: Int {
    case idUndefined
    case idSearchResults
	case idStartHere
	case idPreferences
    case idSmallMap
	case idHelpDots
	case idStartup
    case idDetails
    case idActions   // iPhone
	case idBigMap
    case idSearch
	case idCrumbs
	case idDebug
	case idData
	case idHelp
	case idNote
	case idMain
}

enum ZSignalKind: Int {
    case sData
    case sMain
	case sSwap
    case sDatum
    case sError
    case sFound
	case sStatus
	case sResize
	case sSearch
	case sCrumbs
	case sBigMap
	case sDetails
    case sRelayout
    case sSmallMap
	case sLaunchDone
    case sAppearance
    case sPreferences
	case sStartupButtons
	case sStartupProgress
}

let gControllers = ZControllers()

class ZControllers: NSObject {

	var currentController: ZGenericController?
    var signalObjectsByControllerID = [ZControllerID : ZSignalObject] ()

	// MARK:- hide / reveal
	// MARK:-

	func showEssay(forGuide: Bool) {
		let recordName = forGuide ? "75F7C2D3-4493-4E30-80D8-2F1F60DA7069" : "96689264-EB25-49CC-9324-913BA5CEBD56"

		if  let    e = gEssayView,
			let zone = gRemoteStorage.maybeZoneForRecordName(recordName) {
			e.resetCurrentEssay(zone.note)
			swapMapAndEssay(force: .wEssayMode)
			gSignal([.sCrumbs, .sDetails])
		}
	}

	func swapMapAndEssay(force mode: ZWorkMode? = nil) {
		let newMode      = mode ?? (gIsNoteMode ? .wBigMapMode : .wEssayMode)

		if  newMode     != gWorkMode {
			gWorkMode 	 = newMode
			let showNote = newMode == .wEssayMode

			FOREGROUND { 	// avoid infinite recursion (generic menu handler invoking map editor's handle key)
				gTextEditor.stopCurrentEdit()
				gEssayView?.setControlBarButtons(enabled: showNote)
				self.signalFor(nil, multiple: [.sSwap, .sCrumbs, .sRelayout])
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
				case .idSmallMap,
					 .idDetails,
					 .idBigMap: return kClearColor      // so rubberband is visible on both map and favorites
				case .idNote:   return .white           // override dark mode, otherwise essay view looks like crap
				default:        return gBackgroundColor // respects dark mode
			}
		}

		return gAccentColor
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

	func signalFor(_ object: Any? = nil, regarding: ZSignalKind, onCompletion: Closure? = nil) {
        signalFor(object, multiple: [regarding], onCompletion: onCompletion)
    }

	func signalFor(_ object: Any? = nil, multiple: [ZSignalKind], onCompletion: Closure? = nil) {
		let startupIDs : [ZControllerID] = [.idStartup, .idHelpDots]

		FOREGROUND(canBeDirect: true) {
			for regarding in multiple {
				for (identifier, signalObject) in self.signalObjectsByControllerID {
                    let closure = {
                        signalObject.closure(object, regarding)
                    }
                    
					switch regarding {  // these non-default cases send a signal only to the one corresponding controller
						case .sMain:            if identifier == .idMain           { closure() }
						case .sStatus:          if identifier == .idData           { closure() }
						case .sCrumbs:          if identifier == .idCrumbs         { closure() }
						case .sBigMap:          if identifier == .idBigMap         { closure() }
						case .sSmallMap:        if identifier == .idSmallMap       { closure() }
						case .sPreferences:     if identifier == .idPreferences    { closure() }
						case .sStartupProgress: if startupIDs.contains(identifier) { closure() }
						default:                                                     closure()
					}
                }
            }

            onCompletion?()
        }
    }

}
