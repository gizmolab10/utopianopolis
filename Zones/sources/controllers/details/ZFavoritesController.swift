//
//  ZFavoritesController.swift
//  Zones
//
//  Created by Jonathan Sand on 5/5/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZFavoritesController: ZGraphController {

	override var isFavorites: Bool { return true }
	@IBOutlet var addButton: ZButton?

	@IBAction func addButtonAction(_ button: ZButton) {
		gFavoritesHereMaybe?.addIdea()
	}

	override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
		if  let c = gDetailsController, !c.hideableIsHidden(for: .Favorites) { // don't send signal to a hidden favorites controller
			super.handleSignal(iSignalObject, kind: iKind)
		}
	}

	override func startup() {
		setup() // viewWillAppear is not called, so piggy back on viewDidLoad, which calls startup
	}

}
