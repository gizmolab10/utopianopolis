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
	var     controllerID : ZControllerID { return .idUndefined }
	var     allowedKinds : ZSignalKindArray { return allowedKindsFor(controllerID) }
	var  disallowedKinds : ZSignalKindArray { return disallowedKindsFor(controllerID) }
    func handleSignal(_ object: Any?, kind: ZSignalKind) {}
	func controllerStartup() {}
	func controllerSetup(with mapView: ZMapView?) {}

	func disallowedKindsFor(_ id: ZControllerID) -> ZSignalKindArray {
		switch id {
		case .idSubscription,
			 .idDataDetails,
			 .idMain:    return [.sResize, .spStartupStatus]
		case .idActions: return [.sResize, .sSearch, .sFound]
		case .idPreferences,
			 .idFavorites,
			 .idMap,
			 .idCrumbs:  return [.sData]             // ignore the signal from the end of process next batch
		default: break
		}

		return [.sResize]
	}

	func allowedKindsFor(_ id: ZControllerID) -> ZSignalKindArray {
		switch id {
			case .idHelpEssayIntroduction, .idHelpEssayGraphicals,
					.idHelpDots:   return [.sAppearance, .sDatum, .sData, .spRelayout, .spMain]
			case .idMap:           return [.sAppearance, .sDatum, .sData, .spRelayout, .sResize, .sLaunchDone, .sToolTips, .spFavorites, .spMap]
			case .idFavorites:     return [.sAppearance, .sDatum, .sData, .spRelayout, .sResize, .sLaunchDone, .sToolTips, .spFavorites, .sDetails]
			case .idPreferences:   return [.sAppearance, .sDatum, .sData, .spPreferences,                                                .sDetails]
			case .idNote:          return [.sAppearance, .sDatum, .sEssay]      // ignore the signal from the end of process next batch
			case .idSearch:        return [.sSearch]
			case .idStartup:       return [.spStartupStatus]
			case .idSubscription:  return [.spSubscription]
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

    override func viewDidLoad() {
        super.viewDidLoad()
		controllerStartup()

		gControllers.setSignalHandler(for: self, iID: controllerID) { [self] object, kind in
			view.zlayer.backgroundColor = gControllers.backgroundColorFor(controllerID).cgColor

			if  shouldHandle(kind) {
                handleSignal(object, kind: kind)
            }
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
