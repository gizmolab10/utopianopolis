//
//  ZSubscriptionController.swift
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

class ZSubscriptionController: ZGenericController {

	override var controllerID: ZControllerID { return .idSubscribe }
	@IBOutlet var subscriptionButtonsView: NSView?
	@IBOutlet var subscriptionStatusView: NSView?

	var rowsChanged = true
	var rows : Int { return 4 }

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vSubscribe) { // ignore if hidden
			update()
		}
	}

	func update() {
		updateCells()
	}

	func updateCells() {
		if  rowsChanged {
			rowsChanged = false
			var prior: ZSubscriptionButton?
			subscriptionButtonsView?.removeAllSubviews()
			for index in 0..<rows {
				let        button = ZSubscriptionButton()
				button.bezelStyle = .roundRect
				button.title      = "foo"
				button.tag        = index
				button.target     = self
				button.action     = #selector(buttonAction)

				subscriptionButtonsView?.addSubview(button)
				button.layoutWithin(self, below: prior)

				prior             = button
			}
		}
	}

	@objc func buttonAction(button: ZSubscriptionButton) {
		let tag = button.tag
	}

	@IBAction func handlePurchaseButton(_ sender: ZButton) {
		gSubscription.licenseToken = ZToken(date: Date(), type: .tMonthly, state: .sSubscribed, value: nil).asString

		update()
	}

}

class ZSubscriptionButton: ZButton {

	func layoutWithin(_ controller: ZSubscriptionController, below prior: ZSubscriptionButton?) {
		snp.makeConstraints { make in
			make.right.equalToSuperview()
			make.left .equalToSuperview().offset( 1.0)

			if  prior == nil {
				make.top.equalToSuperview().offset(2.0)
			} else {
				make.top.equalTo(prior!.snp.bottom).offset(2.0)

				if  tag + 1 == controller.rows {
					make.bottom.equalToSuperview().offset(-2.0)
				}
			}
		}
	}
}
