//
//  ZHelpDotsController.swift
//  iFocus
//
//  Created by Jonathan Sand on 6/16/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit

var gHelpDotsController: ZHelpDotsController? { return gControllers.controllerForID(.idHelpDots) as? ZHelpDotsController }

class ZHelpDotsController : ZGraphController {

	override var controllerID : ZControllerID  { return .idHelpDots }
	override var     hereZone : Zone? { return zone }
	var zone                  : Zone?
	override func startup() {
		setup()
		setupExemplar()
	}

	func setupExemplar() {
		let    record = CKRecord(recordType: kZoneType, recordID: CKRecord.ID(recordName: "exemplar"))
		let      real = Zone(record: record, databaseID: .everyoneID)
		real.zoneName = "This is an Idea"
		zone          = real

		real.addChild(Zone())
		real.addChild(Zone())
		real.addChild(Zone())
	}

}
