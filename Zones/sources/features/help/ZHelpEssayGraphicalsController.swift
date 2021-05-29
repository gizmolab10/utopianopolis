//
//  ZHelpEssayGraphicalsController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/16/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

class ZHelpEssayGraphicalsController : ZGenericController {

	override var controllerID : ZControllerID { return .idHelpEssayGraphicals }

	override func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return super.shouldHandle(kind) && (gHelpWindow?.isVisible ?? false)
	}

	override func startup() {
		setup()

	}

}
