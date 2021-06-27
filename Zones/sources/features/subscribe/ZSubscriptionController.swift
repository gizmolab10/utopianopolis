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

	@IBOutlet var subscriptionStatusLabel : ZTextField?
	@IBOutlet var subscriptionStatusView  : ZView?
	@IBOutlet var subscriptionButtonsView : ZView?
	@IBOutlet var height       : NSLayoutConstraint?
	override  var controllerID : ZControllerID { return .idSubscribe }
	static    var   shared : ZSubscriptionController? { return gControllers.controllerForID(.idSubscribe) as? ZSubscriptionController }
	var               rows : Int    { return ZProducts.shared.products.count }
	var        bannerTitle : String { return showMySubscription ? kSubscription : kSubscribe }
	var showMySubscription = true
	var        rowsChanged = true

	func toggleViews() {
		showMySubscription = !showMySubscription

		gSignal([.sDetails])
	}

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vSubscribe) { // ignore if hidden
			update()
		}
	}

	func update() {
		subscriptionStatusView? .isHidden = !showMySubscription
		subscriptionButtonsView?.isHidden =  showMySubscription
		height?                 .constant =  showMySubscription ? 60.0 : CGFloat(rows) * 21.0 - 1.0

		if  showMySubscription {
			subscriptionStatusLabel?.text = ZSubscription.shared.status
		} else if rowsChanged {
			rowsChanged = false
			var prior: ZSubscriptionButton?
			subscriptionButtonsView?.removeAllSubviews()
			for index in 0..<rows {
				let        button = ZSubscriptionButton()
				let          type = ZProducts.shared.typeFor(index)
				button.action     = #selector(buttonAction)
				button.bezelStyle = .roundRect
				button.title      = type.title
				button.tag        = index
				button.target     = self

				subscriptionButtonsView?.addSubview(button)
				button.layoutWithin(self, below: prior)

				prior             = button
			}
		}
	}

	@objc func buttonAction(button: ZSubscriptionButton) {
		ZProducts.shared.purchaseProduct(at: button.tag)

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
