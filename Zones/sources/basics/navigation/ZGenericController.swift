//
//  ZGenericController.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

class ZGenericController: ZController, ZGeneric {

	var        isVisible = false
	var isHandlingSignal = false
	var     controllerID : ZControllerID { return .idUndefined }
	var     allowedKinds : ZSignalKindArray { return allowedKindsFor(controllerID) }
	var  disallowedKinds : ZSignalKindArray { return disallowedKindsFor(controllerID) }
    func handleSignal(kind: ZSignalKind) {}
	func controllerSetup(with mapView: ZMapView?) {}
	func controllerStartup() {}

	func disallowedKindsFor(_ id: ZControllerID) -> ZSignalKindArray {
		switch id {
		case .idSubscription,
			 .idDataDetails,
			 .idMain:    return [.sResize, .spStartupStatus]
		case .idActions: return [.sResize, .sSearch, .sFound]
			case .idFavoritesMap,
			 .idPreferences,
			 .idMainMap,
			 .idCrumbs:  return [.sData]             // ignore the signal from the end of process next batch
		default: break
		}

		return [.sResize]
	}

	func allowedKindsFor(_ id: ZControllerID) -> ZSignalKindArray {
		switch id {
			case .idHelpEssayIntroduction,
				 .idHelpEssayGraphicals,
				 .idHelpDots:      return [.sAppearance, .sDatum, .sData, .spRelayout, .spMain]
			case .idMainMap:       return [.sAppearance, .sDatum, .sData, .spRelayout, .sResize, .sToolTips, .spMainMap]
			case .idFavoritesMap:  return [.sAppearance, .sDatum, .sData, .spRelayout, .sResize, .sToolTips, .spFavoritesMap, .sDetails]
			case .idPreferences:   return [.sAppearance, .sDatum, .sData, .spPreferences,                                     .sDetails]
			case .idNote:          return [.sAppearance, .sDatum, .sEssay]      // ignore the signal from the end of process next batch
			case .idStartup:       return [.spStartupStatus]
			case .idSubscription:  return [.spSubscription]
			case .idSearch:        return [.sSearch]
			case .idSearchResults: return [.sFound]
			default:               break
		}

		return []
	}

	func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return    (allowedKinds.count == 0 ||                   allowedKinds.contains(kind))
			&& (disallowedKinds.count == 0 ||               !disallowedKinds.contains(kind))
			&& ((gHasFinishedStartup && ![.spStartupStatus,         .sError].contains(kind))
			|| (!gHasFinishedStartup &&  [.spStartupStatus, .spMain, .sData].contains(kind)))
	}

    override func viewWillAppear() {
        super.viewWillAppear()
		controllerStartup()

		gControllers.setSignalHandler(for: self, iID: controllerID) { [self] kind in
			view.zlayer.backgroundColor = gControllers.backgroundColorFor(controllerID).cgColor

			if  shouldHandle(kind) {
				markAsHandlingWhile {
					handleSignal(kind: kind)
				}
            }
        }
    }

	func markAsHandlingWhile(execute: Closure) {
		if !isHandlingSignal {
			isHandlingSignal = true

			execute()

			isHandlingSignal = false
		}
	}

#if os(OSX)

    override func viewDidAppear() {
        super.viewDidAppear()
		isVisible = true
        controllerSetup(with: view as? ZMapView)
    }

	override func viewDidDisappear() {
		super.viewDidDisappear()
		isVisible = false
	}

#elseif os(iOS)

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
		showsSelf = true
        setupForMode()
    }

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		showsSelf = false
	}


#endif

}
