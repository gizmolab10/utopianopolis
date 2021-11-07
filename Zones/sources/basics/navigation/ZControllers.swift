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
	case idHelpEssayIntroduction
	case idHelpEssayGraphicals
    case idSearchResults
	case idSubscription
	case idPreferences
	case idStartHere
    case idSmallMap
	case idHelpDots
	case idControls
	case idStartup
    case idDetails
    case idActions   // iPhone
	case idBigMap
    case idSearch
	case idCrumbs
	case idDebug
	case idData
	case idLink
	case idNote
	case idMain
}

enum ZSignalKind: Int {
	case sAll
	case sData
	case sSwap
    case sDatum
    case sError
	case sEssay
    case sFound
	case sResize
	case sSearch
	case sDetails
    case spRelayout
	case sLaunchDone
    case sAppearance

	// these are filtered below, in signalFor

	case spMain
	case spData
	case spCrumbs
	case spBigMap
	case spSmallMap
    case spPreferences
	case spSubscription
	case spStartupStatus
}

let gControllers = ZControllers()

class ZControllers: NSObject {

	var currentController: ZGenericController?
    var signalObjectsByControllerID = [ZControllerID : ZSignalObject] ()

	// MARK:- hide / reveal
	// MARK:-

	func showEssay(forGuide: Bool) {
		let recordName = forGuide ? "75F7C2D3-4493-4E30-80D8-2F1F60DA7069" : "42F338C4-9055-4921-BBD8-1984DF406052"

		if  let    e = gEssayView,
			let zone = gRemoteStorage.maybeZoneForRecordName(recordName) {
			e.resetCurrentEssay(zone.note)
			swapMapAndEssay(force: .wEssayMode)
			gSignal([.spCrumbs, .sDetails])
		}
	}

	func swapMapAndEssay(force mode: ZWorkMode? = nil) {
		// FOREGROUND { // TODO: avoid infinite recursion (generic menu handler invoking map editor's handle key)
		// do not use FOREGROUND: so click on small map will fully exit the essay editor
		gTextEditor.stopCurrentEdit()

		gWorkMode = mode ?? (gIsEssayMode ? .wMapMode : .wEssayMode)

		gEssayView?.updateTitlesControlAndMode()     // why?
		gEssayView?.enableEssayControls(gIsEssayMode)
		gSignal([.sSwap, .spCrumbs, .spSmallMap])

		if !gIsEssayMode {
			gSignal([.spRelayout])
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

	func signalFor(_ object: Any? = nil, multiple: ZSignalKindArray, onCompletion: Closure? = nil) {
		let startupIDs : [ZControllerID] = [.idStartup, .idHelpDots]

		if  multiple.contains(.spRelayout) {
			gCurrentMapView?.removeAllTextViews()
			gDragView?.setAllSubviewsNeedDisplay()
		}

		FOREGROUND(canBeDirect: true) {
			for regarding in multiple {
				for (identifier, signalObject) in self.signalObjectsByControllerID {
                    let closure = {
                        signalObject.closure(object, regarding)
                    }
                    
					switch regarding {  // these non-default cases send a signal only to the one corresponding controller
						case .spMain:          if identifier == .idMain           { closure() }
						case .spData:          if identifier == .idData           { closure() }
						case .spCrumbs:        if identifier == .idCrumbs         { closure() }
						case .spBigMap:        if identifier == .idBigMap         { closure() }
						case .spSmallMap:      if identifier == .idSmallMap       { closure() }
						case .spPreferences:   if identifier == .idPreferences    { closure() }
						case .spSubscription:  if identifier == .idSubscription   { closure() }
						case .spStartupStatus: if startupIDs.contains(identifier) { closure() }
						default:                                                    closure()
					}
                }
            }

            onCompletion?()
        }
    }

}
