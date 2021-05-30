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

	var     isVisible = false
	var  controllerID : ZControllerID { return .idUndefined }
	var  allowedKinds : ZSignalKindArray { return allowedKindsFor(controllerID) }
    func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {}
	func startup() {}
	func setup() {}

	func allowedKindsFor(_ id: ZControllerID) -> ZSignalKindArray {
		switch id {
			case .idHelpEssayIntroduction,
				 .idHelpEssayGraphicals,
				 .idHelpDots:      return [.sData, .sDatum, .sAppearance, .sRelayout]
			case .idPreferences:   return [.sData, .sDatum, .sAppearance, .sDetails,  .sDetails, .spPreferences]
			case .idSmallMap:      return [.sData, .sDatum, .sAppearance, .sRelayout, .sDetails, .spSmallMap]
			case .idBigMap:        return [.sData, .sDatum, .sAppearance, .sRelayout, .spBigMap]
			case .idSearchResults: break
			case .idStartHere:     break
			case .idControls:      break
			case .idStartup:       break
			case .idDetails:       break
			case .idActions:       break   // iPhone
			case .idSearch:        break
			case .idCrumbs:        break
			case .idDebug:         break
			case .idData:          break
			case .idLink:          break
			case .idHelp:          break
			case .idNote:          break
			case .idMain:          break
			default: break
		}
		return []
	}

	func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return (allowedKinds.count == 0 || allowedKinds.contains(kind))
			&& (( gHasFinishedStartup && ![.spStartupStatus, .sError].contains(kind)) ||
				(!gHasFinishedStartup &&  [.spStartupStatus,  .spMain].contains(kind)))
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

	override func viewDidLayout() {
		super.viewDidLayout()
		gMainWindow?.updateEssayEditorInspectorBar(show: gIsEssayMode)
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
        setup()
    }

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		isVisible = false
	}


#endif

}
