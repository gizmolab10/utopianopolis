//
//  ZLicenseController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/20/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZLicenseController: ZGenericController {

	override  var   controllerID: ZControllerID { return .idLicense }
	@IBOutlet var      typeLabel: ZTextField?
	@IBOutlet var     stateLabel: ZTextField?
	@IBOutlet var purchaseButton: NSButton?

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vLicense) { // ignore if hidden
			update()
		}
	}

	func update() {
		if  let        token = gLicense.licenseToken?.asZToken {
			let        state = token.state
			stateLabel?.text = state.title
			typeLabel? .text = token .type.title
			purchaseButton?.isEnabled = (state == .sReady)
		}
	}

	@IBAction func handlePurchaseButton(_ sender: ZButton) {
		gLicense.licenseToken = ZToken(date: Date(), type: .tMonthly, state: .sLicensed, value: nil).asString

		update()
	}

}