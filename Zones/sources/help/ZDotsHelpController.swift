//
//  ZDotsHelpController.swift
//  iFocus
//
//  Created by Jonathan Sand on 6/16/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

var gDotsHelpController: ZDotsHelpController? { return gControllers.controllerForID(.idDotsHelp) as? ZDotsHelpController }

class ZDotsHelpController : ZGraphController {

	override var controllerID : ZControllerID  { return .idDotsHelp }
	override var     hereZone : Zone? { return zone }
	var zone                  : Zone?
	override func startup() { setup() }

	func setupExample() {
//		if  let mimic = gHereMaybe,
//			let  dbid = mimic.databaseID {
//			let  real = Zone(record: mimic.record, databaseID: dbid)
//			zone      = real
//
//			real.addChild(Zone())
//			real.addChild(Zone())
//			real.addChild(Zone())
//		}
	}

}
