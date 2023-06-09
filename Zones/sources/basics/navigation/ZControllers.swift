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
	case idSearchOptions
	case idSubscription
	case idFavoritesMap
	case idDataDetails
	case idPreferences
	case idDebugAngles
	case idStartHere
	case idHelpDots
	case idControls
	case idStartup
    case idDetails
    case idActions   // iPhone
	case idMainMap
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
	case sDetails         // recompute and display all details except favorites map
	case sToolTips        // remove and reassign all tool tips
	case sLaunchDone
    case sAppearance

	// the following are sent to one (* or two) specific controller(s)

	case spMainMap        // relayout main map
	case spRelayout       // relayout both maps *
	case spDataDetails    // update the data view in details
	case spPreferences
	case spSubscription
	case spFavoritesMap   // relayout favorites map
	case spStartupStatus  // startup and help *
	case spCrumbs
	case spDebug
	case spMain
}

let gControllers = ZControllers()

func gDispatchSignals(_ multiple: ZSignalKindArray, _ closure: Closure? = nil) { gControllers.dispatchSignalsFor(multiple: multiple, onCompletion: closure) }
func gSwapMapAndEssay(force mode: ZWorkMode? = nil, _ closure: Closure? = nil) { gControllers.swapMapAndEssay(force: mode, closure) }
func gControllerForID(_ iID: ZControllerID?)            -> ZGenericController? { return gControllers.controllerForID(iID) }
func gShowEssay(forGuide: Bool)                                                { gControllers.showEssay(forGuide: forGuide) }

class ZControllers: NSObject {

	var currentController: ZGenericController?
    var signalRespondersByControllerID = [ZControllerID : ZSignalResponder] ()

	// MARK: - hide / reveal
	// MARK: -

	func showEssay(forGuide: Bool) {
		let recordName = forGuide ? "75F7C2D3-4493-4E30-80D8-2F1F60DA7069" : "8F42BAA6-55CC-42F3-A3E3-5F76423B3887"
		if  let    e = gEssayView,
			let zone = gMaybeZoneForRecordName(recordName) {
			e.resetCurrentEssay(zone.note)
			swapMapAndEssay(force: .wEssayMode)
			gDispatchSignals([.spCrumbs, .sDetails])
		}
	}

	func swapMapAndEssay(force mode: ZWorkMode? = nil, _ closure: Closure? = nil) {
		// FOREGROUND { // TODO: avoid infinite recursion (generic menu handler invoking map editor's handle key)
		// do not use FOREGROUND: so click on favorites map will fully exit the essay editor
		gTextEditor.stopCurrentEdit()
		gHideExplanation()

		gWorkMode = mode ?? (gIsEssayMode ? .wMapMode : .wEssayMode)

		if  gIsEssayMode {
			gEssayControlsView?.updateTitlesControlAndMode()
		} else {
			gMainWindow?.revealEssayEditorInspectorBar(false)
		}

		gDispatchSignals([.sSwap, .spRelayout, .spCrumbs, .spDataDetails])

		closure?()
	}

	// MARK: - registry
	// MARK: -

	func controllerForID(_ iID: ZControllerID?) -> ZGenericController? {
		if  let identifier = iID,
			let     object = signalRespondersByControllerID[identifier] {
			return  object.controller
		}

		return nil
	}

	func setSignalHandler(for iController: ZGenericController, iID: ZControllerID, closure: @escaping SignalKindClosure) {
		signalRespondersByControllerID[iID] = ZSignalResponder(closure, forController: iController)
        currentController                   = iController
    }

	func clearSignalHandler(_ iID: ZControllerID) {
		signalRespondersByControllerID[iID] = nil
    }

	func backgroundColorFor(_ iID: ZControllerID?) -> ZColor {
		if  let id = iID {
			switch id {
				case .idFavoritesMap,
					 .idDetails,
					 .idMainMap: return kClearColor      // so rubberband is visible on both map and favorites
				case .idNote:    return .white           // override dark mode, otherwise essay view looks like crap
				default:         return gBackgroundColor // respects dark mode
			}
		}

		return gAccentColor
	}

	// MARK: - signals
    // MARK: -

	class ZSignalResponder {
		let    closure : SignalKindClosure!
		let controller : ZGenericController!

		init(_ iClosure: @escaping SignalKindClosure, forController iController: ZGenericController) {
			controller = iController
			closure    = iClosure
		}
	}

	func dispatchSignalsFor(multiple regards: ZSignalKindArray, onCompletion: Closure? = nil) {
		FOREGROUND { [self] in
			for regarding in regards {
				for (controllerID, signalResponder) in signalRespondersByControllerID {
                    let closure = {
						signalResponder.closure(regarding)
                    }
                    
					switch (regarding, controllerID) {  // these non-default cases send a signal only to the one (or two) corresponding controller)s)
						case (.spMain,         .idMain):         closure()
						case (.spDebug,        .idDebug):        closure()
						case (.spCrumbs,       .idCrumbs):       closure()
						case (.spMainMap,      .idMainMap):      closure()
						case (.spDataDetails,  .idDataDetails):  closure()
						case (.spPreferences,  .idPreferences):  closure()
						case (.spFavoritesMap, .idFavoritesMap): closure()
						case (.spSubscription, .idSubscription): closure()
						default:
							let     mapCIDs : [ZControllerID] = [.idMainMap, .idFavoritesMap]
							let startupCIDs : [ZControllerID] = [.idStartup, .idHelpDots]

							switch regarding {
								case .spRelayout:      if     mapCIDs.contains(controllerID) { closure() }
								case .spStartupStatus: if startupCIDs.contains(controllerID) { closure() }
								default:                                                       closure()
							}
					}
                }
            }

            onCompletion?()
        }
    }

}
