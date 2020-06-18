//
//  ZHelpDotsExplanationController.swift
//  iFocus
//
//  Created by Jonathan Sand on 6/16/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit

var gHelpDotsExplanationController: ZHelpDotsExplanationController? { return gControllers.controllerForID(.idHelpDots) as? ZHelpDotsExplanationController }

class ZHelpDotsExplanationController : ZGraphController {

	override  var controllerID : ZControllerID { return .idHelpDots }
	override  var   widgetType : ZWidgetType   { return .tExemplar }
	override  var   isExemplar : Bool          { return true }
	override  var     hereZone : Zone?         { return zone }
	override  var allowedKinds : [ZSignalKind] { return [.sRelayout, .sData, .sDatum, .sStartup] }
	var                   zone : Zone?
	@IBOutlet var     topLabel : ZTextField?
	@IBOutlet var  bottomLabel : ZTextField?

	override func startup() {
		setup()
		setupExemplar()

		topLabel?   .text = "As this drawing illustrates, each idea in Seriously has as many as two dots, one on each side."
		bottomLabel?.text = "\t• The drag dot (at left) is used to select, deselect and drag the idea.\n\t• The reveal dot (at right) is used to reveal or conceal its list, or activate the idea.\n\nThese dots are sometimes decorated, concisely prividing further information about the idea. This information is explained in the table below."
	}

	func setupExemplar() {
		let     record = CKRecord(recordType: kZoneType, recordID: CKRecord.ID(recordName: kExemplarName))
		let       real = Zone(record: record, databaseID: .everyoneID)
		real.zoneName  = "this is a typical idea, with 3 ideas in its (hidden) list"
		zone           = real

		real.addChild(Zone())
		real.addChild(Zone())
		real.addChild(Zone())
	}

}