//
//  ZStartupController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/2/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

var gStartupController: ZStartupController? { return gControllers.controllerForID(.idStartup) as? ZStartupController }

class ZStartupController: ZGenericController {

	override  var controllerID     : ZControllerID { return .idStartup }
	@IBOutlet var enableCloudDrive : ZTextField?
	@IBOutlet var acccessToAppleID : ZView?
	@IBOutlet var pleaseWait       : ZView?
	@IBOutlet var thermometerBar   : ZStartupProgressBar?

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		if iKind == .sStartup {
			acccessToAppleID?.isHidden =  gHasAccessToAppleID
			enableCloudDrive?.isHidden = !gHasAccessToAppleID || gCloudDriveIsEnabled
			pleaseWait?      .isHidden = !gCloudDriveIsEnabled

			updateThermometerBar()
		}
	}

	func updateThermometerBar() {
		if !gHasFinishedStartup,
			gCloudDriveIsEnabled {
			thermometerBar?.update()
			view.setAllSubviewsNeedDisplay()
		}
	}

	@IBAction func handlePermissionAction(_ button: ZButton) {
		let      identifier = convertFromOptionalUserInterfaceItemIdentifier(button.identifier)

		switch   identifier {
			case    "id yes": gHasAccessToAppleID  = true
			case "drive yes": gCloudDriveIsEnabled = true

			default:          gApplication.terminate(self)
		}

		gSignal([.sStartup])
		view.setAllSubviewsNeedDisplay()
	}

}
