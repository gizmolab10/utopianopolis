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
	func startup() {}
	func setup() {}

	func disallowedKindsFor(_ id: ZControllerID) -> ZSignalKindArray {
		switch id {
			case .idSubscription,
				 .idData,
				 .idMain:    return [.spStartupStatus]
			case .idActions: return [.sSearch, .sFound]
			case .idBigMap:  return [.sData]             // ignore the signal from the end of process next batch
			default: break
		}

		return []
	}

	func allowedKindsFor(_ id: ZControllerID) -> ZSignalKindArray {
		switch id {
			case .idHelpEssayIntroduction,
				 .idHelpEssayGraphicals,
				 .idHelpDots:      return [.sData, .sDatum, .sAppearance, .sRelayout]
			case .idBigMap:        return [.sData, .sDatum, .sAppearance, .sRelayout,     .spBigMap, .sLaunchDone]
			case .idSmallMap:      return [.sData, .sDatum, .sAppearance, .sRelayout,     .sDetails, .sLaunchDone, .spSmallMap]
			case .idPreferences:   return [.sData, .sDatum, .sAppearance, .spPreferences, .sDetails]
			case .idSearchResults: return [.sFound]
			case .idSearch:        return [.sSearch]
			case .idStartup:       return [.spStartupStatus] // .sStartupButtons
			case .idNote:          return [.sEssay, .sAppearance]             // ignore the signal from the end of process next batch
			default: break
		}

		return []
	}

	func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return    (allowedKinds.count == 0 ||                    allowedKinds.contains(kind))
			&& (disallowedKinds.count == 0 ||                !disallowedKinds.contains(kind))
			&& ((gHasFinishedStartup && ![.spStartupStatus,          .sError].contains(kind))
			|| (!gHasFinishedStartup &&  [.spStartupStatus,  .spMain, .sData].contains(kind)))
	}

    override func viewDidLoad() {
        super.viewDidLoad()
		startup()

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
        setup()
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
