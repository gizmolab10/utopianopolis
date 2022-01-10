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
	func controllerSetup() {}

	func disallowedKindsFor(_ id: ZControllerID) -> ZSignalKindArray {
		switch id {
			case .idSubscription,
				 .idDataDetails,
				 .idMain:    return [.sResize, .spStartupStatus]
			case .idActions: return [.sResize, .sSearch, .sFound]
			case .idBigMap:  return [.sData]             // ignore the signal from the end of process next batch
			default: break
		}

		return [.sResize]
	}

	func allowedKindsFor(_ id: ZControllerID) -> ZSignalKindArray {
		switch id {
			case .idHelpEssayIntroduction,
				 .idHelpEssayGraphicals,
				 .idHelpDots:      return [.sData, .sDatum, .sAppearance, .spRelayout]
			case .idBigMap:        return [.sData, .sDatum, .sAppearance, .spRelayout,     .sResize,  .sLaunchDone, .spBigMap]
			case .idSmallMap:      return [.sData, .sDatum, .sAppearance, .spRelayout,     .sDetails, .sLaunchDone, .spSmallMap]
			case .idPreferences:   return [.sData, .sDatum, .sAppearance, .spPreferences, .sDetails]
			case .idSearchResults: return [.sFound]
			case .idSearch:        return [.sSearch]
			case .idStartup:       return [.spStartupStatus]
			case .idNote:          return [.sEssay, .sAppearance]             // ignore the signal from the end of process next batch
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

        gControllers.setSignalHandler(for: self, iID: controllerID) { object, kind in
			self.view.zlayer.backgroundColor = gControllers.backgroundColorFor(self.controllerID).cgColor

			if  self.shouldHandle(kind) {
                self.handleSignal(object, kind: kind)
            }
        }
    }

#if os(OSX)

    override func viewDidAppear() {
        super.viewDidAppear()
		isVisible = true
        controllerSetup()
    }

	override func viewDidDisappear() {
		super.viewDidDisappear()
		isVisible = false
	}

#elseif os(iOS)

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
		isVisible = true
        setupForMode()
    }

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		isVisible = false
	}


#endif

}
