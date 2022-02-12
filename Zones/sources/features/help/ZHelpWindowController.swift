//
//  ZHelpWindowController.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/11/22.
//  Copyright © 2022 Zones. All rights reserved.
//

import Foundation

class ZHelpWindowController : ZWindowController {

	override func close() {
		super.close()
		gRelayoutMaps()
	}
}
