//
//  ZHelpEssayMapController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/16/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

class ZHelpEssayMapController : ZGenericTableController {

	override  var controllerID : ZControllerID { return .idHelpDots }
	override  var allowedKinds : [ZSignalKind] { return [.sRelayout, .sData, .sDatum, .sStartupProgress] }
	@IBOutlet var     topLabel : ZTextField?
	@IBOutlet var  bottomLabel : ZTextField?

	override func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return super.shouldHandle(kind) && (gHelpWindow?.isVisible ?? false)
	}

	override func startup() {
		setup()

		topLabel?   .font = kLargeHelpFont
		topLabel?   .text = "Essays and notes"
		bottomLabel?.font = kLargeHelpFont
		bottomLabel?.text = "All of this is explained in detail in the table below"
	}

}
