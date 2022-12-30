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

var gSubscriptionController : ZSubscriptionController? { return gControllers.controllerForID(.idSubscription) as? ZSubscriptionController }
var gSubscriptionDidChange  = true

class ZSubscriptionController: ZGenericController {

	@IBOutlet var    dateLabel : ZTextField?
	@IBOutlet var  statusLabel : ZTextField?
	@IBOutlet var  statusView  : ZView?
	@IBOutlet var buttonsView  : ZView?
	@IBOutlet var cancelButton : ZButton?
	override  var controllerID : ZControllerID { return .idSubscription }
	var            bannerTitle : String        { return gShowMySubscriptions ? kSubscription : kSubscribe }
	var                   rows : Int           { return gProducts.products.count }

	func toggleViews() {
		gShowMySubscriptions = !gShowMySubscriptions

		subscriptionUpdate()
	}

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vSubscribe) { // ignore if hidden
			subscriptionUpdate()
		}
	}

	func subscriptionUpdate() {
		statusView?      .isHidden = !gShowMySubscriptions
		buttonsView?     .isHidden =  gShowMySubscriptions

		if  gShowMySubscriptions {
			dateLabel?       .text = gProducts.expires
			statusLabel?     .text = gProducts.status
			cancelButton?.isHidden = !(gProducts.zToken?.type.isAutoRenew ?? false)
		} else if gSubscriptionDidChange  {
			gSubscriptionDidChange  = false
			var prior: ZSubscriptionButton?
			buttonsView?.removeAllSubviews()
			for index in 0..<rows {
				let         button = ZSubscriptionButton()
				let           type = gProducts.typeFor(index)
				button.action      = #selector(buttonAction)
				button.bezelColor  = gAccentColor
				button.bezelStyle  = .roundRect
				button.title       = type.title
				button.tag         = index
				button.target      = self

				buttonsView?.addSubview(button)
				button.layoutWithin(self, below: prior)

				prior             = button
			}
		}
	}

	@IBAction func handleCancelAction(button: ZButton) {
		gAlerts.showAlert(
			"How to cancel your subscription",
			["1. Open the App Store app.",
			 "2. Click the sign-in button, or your name at the bottom of the sidebar.",
			 "3. Click 'View Information' at the top of the window. You might be asked to sign in.",
			 "4. On the page that appears, scroll until you see 'Subscriptions', then click 'Manage'.",
			 "5. Click 'Edit' next to the subscription that you want.",
			 "6. Click 'Cancel Subscription'. If you don’t see 'Cancel Subscription', then the subscription is already canceled and won't renew. "].joined(separator: "\n"),
			"OK", "My subscription is missing!",
			alertWidth: CGFloat(700.0)) { status in
			if  status == .sNo {
				"https://support.apple.com/en-us/HT212052".openAsURL()
			}
		}
	}

	@objc func buttonAction(button: ZSubscriptionButton) {
		gProducts.purchaseProduct(at: button.tag)

		subscriptionUpdate()
	}

}

class ZSubscriptionButton: ZButton {

	func layoutWithin(_ controller: ZSubscriptionController, below above: ZSubscriptionButton?) {
		let   last = tag == controller.rows - 1
		let margin = 8.0

		snp.makeConstraints { make in
			make.left .equalToSuperview().offset(margin)
			make.right.equalToSuperview() .inset(margin)

			if  let a = above {
				make.top.equalTo(a.snp.bottom)

				if  last {
					make.bottom.equalToSuperview().inset(margin)
				}
			} else {
				make.top.equalToSuperview().offset(margin)
			}
		}

		heightAnchor.constraint(equalToConstant: 21.0).isActive = true

		setNeedsLayout()
	}

}
