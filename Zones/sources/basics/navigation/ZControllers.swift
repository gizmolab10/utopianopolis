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
	case idDataDetails
	case idPreferences
	case idDebugAngles
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
	case idLink
	case idNote
	case idMain
}

enum ZSignalKind: Int {
	case sAll
	case sData            // relayout all ideas
	case sSwap            // between notes and map
    case sDatum           // redraw single idea
    case sError
	case sEssay           // redraw titles in essays (indent, drag dot)
    case sFound
	case sResize          // resize window
	case sSearch
	case sDetails         // recompute and display all details except small map
	case sToolTips        // remove and reassign all tool tips
	case sLaunchDone
    case sAppearance

	// the following are sent to one (* or two) specific controller(s)

	case spBigMap         // relayout main map
	case spRelayout       // relayout both maps *
	case spSmallMap       // relayout favorites map
	case spDataDetails    // update the data view in details
	case spPreferences
	case spSubscription
	case spStartupStatus  // startup and help *
	case spCrumbs
	case spDebug
	case spMain
}

let gControllers = ZControllers()

class ZControllers: NSObject {

	var currentController: ZGenericController?
    var signalObjectsByControllerID = [ZControllerID : ZSignalObject] ()

	// MARK: - hide / reveal
	// MARK: -

	func showEssay(forGuide: Bool) {
		let recordName = forGuide ? "75F7C2D3-4493-4E30-80D8-2F1F60DA7069" : "8F42BAA6-55CC-42F3-A3E3-5F76423B3887"
		if  let    e = gEssayView,
			let zone = gRemoteStorage.maybeZoneForRecordName(recordName) {
			e.resetCurrentEssay(zone.note)
			swapMapAndEssay(force: .wEssayMode)
			gSignal([.spCrumbs, .sDetails])
		}
	}

	func swapMapAndEssay(force mode: ZWorkMode? = nil, _ closure: Closure? = nil) {
		// FOREGROUND { // TODO: avoid infinite recursion (generic menu handler invoking map editor's handle key)
		// do not use FOREGROUND: so click on small map will fully exit the essay editor
		gTextEditor.stopCurrentEdit()
		gHideExplanation()

		gWorkMode = mode ?? (gIsEssayMode ? .wMapMode : .wEssayMode)

		if  gIsEssayMode {
			gEssayControlsView?.updateTitlesControlAndMode()
		} else {
			gMainWindow?.revealEssayEditorInspectorBar(false)
		}

		gSignal([.sSwap, .spRelayout, .spCrumbs, .spSmallMap])

		closure?()
	}

	// MARK: - registry
	// MARK: -

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

	// MARK: - signals
    // MARK: -

	class ZSignalObject {
		let    closure : SignalClosure!
		let controller : ZGenericController!

		init(_ iClosure: @escaping SignalClosure, forController iController: ZGenericController) {
			controller = iController
			closure    = iClosure
		}
	}

	func signalFor(_ object: Any? = nil, multiple: ZSignalKindArray, onCompletion: Closure? = nil) {
		FOREGROUND { [self] in
			if  multiple.contains(.spRelayout) {
				gWidgets.clearAll()
				gMapView?.updateTracking()
				gMapView?.removeAllTextViews(ofType: .both)
			}

			for regarding in multiple {
				for (cid, signalObject) in signalObjectsByControllerID {
                    let closure = {
                        signalObject.closure(object, regarding)
                    }
                    
					switch (regarding, cid) {  // these non-default cases send a signal only to the one (or two) corresponding controller)s)
						case (.spMain,         .idMain):         closure()
						case (.spDebug,        .idDebug):        closure()
						case (.spCrumbs,       .idCrumbs):       closure()
						case (.spBigMap,       .idBigMap):       closure()
						case (.spSmallMap,     .idSmallMap):     closure()
						case (.spDataDetails,  .idDataDetails):  closure()
						case (.spPreferences,  .idPreferences):  closure()
						case (.spSubscription, .idSubscription): closure()
						default:
							let     mapCIDs : [ZControllerID] = [.idBigMap,  .idSmallMap]
							let startupCIDs : [ZControllerID] = [.idStartup, .idHelpDots]

							switch regarding {
								case .spRelayout:      if     mapCIDs.contains(cid) { closure() }
								case .spStartupStatus: if startupCIDs.contains(cid) { closure() }
								default:                                              closure()
							}
					}
                }
            }

            onCompletion?()
        }
    }

}
