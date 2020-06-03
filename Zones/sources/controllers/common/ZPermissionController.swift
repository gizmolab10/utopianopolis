//
//  ZPermissionController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/2/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

var gPermissionController: ZPermissionController? { return gControllers.controllerForID(.idStartup) as? ZPermissionController }

class ZPermissionController: ZGenericController {

	override  var controllerID     : ZControllerID { return .idStartup }
	@IBOutlet var enableCloudDrive : ZTextField?
	@IBOutlet var acccessToAppleID : ZView?
	@IBOutlet var oneMomentLabel   : ZView?

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		acccessToAppleID?.isHidden =  gHasAccessToAppleID
		enableCloudDrive?.isHidden = !gHasAccessToAppleID || gCloudDriveIsEnabled
		oneMomentLabel?  .isHidden = !gCloudDriveIsEnabled
	}

	@IBAction func handlePermissionAction(_ button: ZButton) {
		let    identifier = convertFromOptionalUserInterfaceItemIdentifier(button.identifier)

		switch identifier {
			case "id yes":    gHasAccessToAppleID  = true
			case "drive yes": gCloudDriveIsEnabled = true

			default:          gApplication.terminate(self)
		}

		gSignal([.sStartup])
		view.setAllSubviewsNeedDisplay()
	}

}
