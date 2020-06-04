//
//  ZStartupController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/2/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import AuthenticationServices

var gStartupController: ZStartupController? { return gControllers.controllerForID(.idStartup) as? ZStartupController }

class ZStartupController: ZGenericController, ASAuthorizationControllerDelegate {

	override  var controllerID     : ZControllerID { return .idStartup }
	@IBOutlet var enableCloudDrive : ZTextField?
	@IBOutlet var acccessToAppleID : ZView?
	@IBOutlet var pleaseWait       : ZView?
	@IBOutlet var thermometerBar   : ZStartupProgressBar?

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		if  iKind == .sStartup {
			acccessToAppleID?.isHidden =  gHasAccessToAppleID
			enableCloudDrive?.isHidden = !gHasAccessToAppleID  || gCloudStatusIsActive
			pleaseWait?      .isHidden = !gCloudStatusIsActive

			updateThermometerBar()
		}
	}

	func updateThermometerBar() {
		if !gHasFinishedStartup {
			thermometerBar?.update()
			view.setAllSubviewsNeedDisplay()
		}
	}

	@IBAction func handlePermissionAction(_ button: ZButton) {
		let      identifier = convertFromOptionalUserInterfaceItemIdentifier(button.identifier)

		switch   identifier {
			case    "id yes": accessAppleID()
			case "drive yes": break

			default:          gApplication.terminate(self)
		}

		view.setAllSubviewsNeedDisplay()
		gSignal([.sStartup])
	}

	func accessAppleID() {
		if !gHasAccessToAppleID {
			let                     provider = ASAuthorizationAppleIDProvider()
			let                      request = provider.createRequest()
			request         .requestedScopes = [.fullName, .email]
			let      authorizationController = ASAuthorizationController(authorizationRequests: [request])
			authorizationController.delegate = self

			authorizationController.performRequests()
		}
	}

	func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
		gHasAccessToAppleID  = true

		view.setAllSubviewsNeedDisplay()
		gSignal([.sStartup])
	}

}
