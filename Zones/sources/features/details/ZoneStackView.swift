//
//  ZoneStackView.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/8/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

class ZoneStackView: ZStackView {

	var needsSmallMapUpdate = false

	func setNeedsSmallMapUpdate() {
		needsSmallMapUpdate = true
	}

	@objc func setup() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleNote), name: NSNotification.Name("frameDidChangeNotification"), object: nil)

		postsFrameChangedNotifications = true
	}

	@objc func handleNote(_ note: Notification) {
		if  needsSmallMapUpdate {
			needsSmallMapUpdate = false

			gSmallMapController?.updateSmallMap()
		}
	}

}
