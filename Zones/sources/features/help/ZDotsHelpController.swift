//
//  ZDotsHelpController.swift
//  iFocus
//
//  Created by Jonathan Sand on 6/16/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit

var gDotsHelpController: ZHelpDotsController? { return gControllers.controllerForID(.idDotsHelp) as? ZHelpDotsController }

class ZHelpDotsController : ZGraphController {

    var zone                  : Zone?
	override var     hereZone : Zone? { return zone }
    override var controllerID : ZControllerID  { return .idDotsHelp }
    override func restartGestureRecognition() {}

    override func startup() {
		setup()
		setupExemplar()
    }

	func setupExemplar() {
		let     record = CKRecord(recordType: kZoneType, recordID: CKRecord.ID(recordName: kExemplarName))
		let       real = Zone(record: record, databaseID: .everyoneID)
		real.zoneName  = "This is the Text of an Idea"
        real.colorized = false
		zone           = real

		real.addChild(Zone())
		real.addChild(Zone())
		real.addChild(Zone())
	}

}
