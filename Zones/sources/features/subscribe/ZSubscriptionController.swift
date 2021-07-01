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

class ZSubscriptionController: ZGenericController {

	@IBOutlet var cancelButton : ZButton?
	@IBOutlet var  buttonsView : ZView?
	@IBOutlet var   statusView : ZView?
	@IBOutlet var  statusLabel : ZTextField?
	@IBOutlet var    dateLabel : ZTextField?
	@IBOutlet var       height : NSLayoutConstraint?
	override  var controllerID : ZControllerID { return .idSubscription }
	var               rows : Int    { return gProducts.products.count }
	var        bannerTitle : String { return gShowMySubscriptions ? kSubscription : kSubscribe }
	var        rowsChanged = true

	func toggleViews() {
		gShowMySubscriptions = !gShowMySubscriptions

		update()
	}

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vSubscribe) { // ignore if hidden
			update()
		}
	}

	func update() {
		statusView? .isHidden = !gShowMySubscriptions
		buttonsView?.isHidden =  gShowMySubscriptions
		height?     .constant =  gShowMySubscriptions ? 84.0 : CGFloat(rows) * 26.0 - 3.0

		if  gShowMySubscriptions {
			dateLabel?  .text = gSubscription.acquired
			statusLabel?.text = gSubscription.status
		} else if rowsChanged {
			rowsChanged = false
			var prior: ZSubscriptionButton?
			buttonsView?.removeAllSubviews()
			for index in 0..<rows {
				let        button = ZSubscriptionButton()
				let          type = gProducts.typeFor(index)
				button.action     = #selector(buttonAction)
				button.bezelColor = gAccentColor
				button.bezelStyle = .roundRect
				button.title      = type.title
				button.tag        = index
				button.target     = self

				buttonsView?.addSubview(button)
				button.layoutWithin(self, below: prior)

				prior             = button
			}
		}
	}

	@objc func buttonAction(button: ZSubscriptionButton) {
		gProducts.purchaseProduct(at: button.tag)

		update()
	}

}

class ZSubscriptionButton: ZButton {

	func layoutWithin(_ controller: ZSubscriptionController, below prior: ZSubscriptionButton?) {
		let   last = tag == controller.rows - 1
		let margin = 8.0

		snp.makeConstraints { make in
			make.left .equalToSuperview().offset(margin)
			make.right.equalToSuperview() .inset(margin)

			if  let p = prior {
				make.top.equalTo(p.snp.bottom)

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
