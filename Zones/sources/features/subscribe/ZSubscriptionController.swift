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

var gSubscriptionController: ZSubscriptionController? { return gControllers.controllerForID(.idSubscribe) as? ZSubscriptionController }

class ZSubscriptionController: ZGenericController {

	override var controllerID: ZControllerID { return .idSubscribe }
	@IBOutlet var height: NSLayoutConstraint?
	@IBOutlet var subscriptionButtonsView: ZView?
	@IBOutlet var subscriptionStatusView:  ZView?

	var rows : Int { return ZSubscriptionType.varieties }
	var rowsChanged = true
	var showSubscriptions = false
	var bannerTitle: String { return showSubscriptions ? kSubscriptions : kSubscribe }

	func toggleViews() {
		showSubscriptions = !showSubscriptions

		gSignal([.sDetails])
	}

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vSubscribe) { // ignore if hidden
			update()
		}
	}

	func update() {
		subscriptionButtonsView?.isHidden = showSubscriptions
		height?.constant = showSubscriptions ? 54.0 : CGFloat(rows) * 22.0 - 5.0

		if  showSubscriptions {


		} else if rowsChanged {
			rowsChanged = false
			var prior: ZSubscriptionButton?
			subscriptionButtonsView?.removeAllSubviews()
			for index in 0..<rows {
				let        button = ZSubscriptionButton()
				let          type = ZSubscriptionType.typeFor(index)
				button.bezelStyle = .roundRect
				button.title      = type.title
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
		let                   type = ZSubscriptionType.typeFor(button.tag)
		gSubscription.licenseToken = ZToken(date: Date(), type: type, state: .sSubscribed, value: nil).asString

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
