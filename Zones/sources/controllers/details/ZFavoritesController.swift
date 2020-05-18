//
//  ZFavoritesController.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/5/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

enum ZFavoritesControlType: String {
	case eConfining = "browse"
	case eGrowth    = "grow"
	case eMode      = "mode"
	case eAdd       = "add"
}

class ZFavoritesController: ZGraphController {

	override var isFavorites: Bool { return true }
	@IBOutlet var controlsView: ZFavoritesControlsView?

	override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
		if  let c = gDetailsController, !c.hideableIsHidden(for: .Favorites) { // don't send signal to a hidden favorites controller
			super.handleSignal(iSignalObject, kind: iKind)
		}
	}

	override func startup() {
		setup() // viewWillAppear is not called, so piggy back on viewDidLoad, which calls startup
		controlsView?.updateAndRedraw()
	}

}
