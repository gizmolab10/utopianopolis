//
//  ZHelpDotsExemplarController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/16/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

var gHelpHyperlinkColor: ZColor { return gIsDark ? kSystemBlue.lighter(by: 3.0) : kSystemBlue.darker(by: 4.0) }

class ZHelpDotsExemplarController : ZMapController {

	override  var controllerID : ZControllerID { return .idHelpDots }
	override  var   widgetType : ZWidgetType   { return .tExemplar }
	override  var   isExemplar : Bool          { return true }
	override  var     hereZone : Zone?         { return zone }
	override  var allowedKinds : [ZSignalKind] { return [.sRelayout, .sData, .sDatum, .sStartupStatus, .sAppearance] }
	var                   zone : Zone?
	@IBOutlet var     topLabel : ZTextField?
	@IBOutlet var  bottomLabel : ZTextField?

	override func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return super.shouldHandle(kind) && (gHelpWindow?.isVisible ?? false)
	}

	override func startup() {
		setup()
		setupExemplar()

		topLabel?   .font = kLargeHelpFont
		topLabel?   .text = "All ideas in Seriously have a drag dot on the left. Many have a reveal dot on the right."
		bottomLabel?.font = kLargeHelpFont
		bottomLabel?.text = "\t• The drag dot (at left) is used to select, deselect and drag the idea\n\t• The reveal dot (at right) is used to show or hide its list, or activate the idea\n\nThese dots are often decorated, providing further information about the idea (see below)."
		mapView?.addBorder(thickness: 0.5, radius: 0.0, color: kDarkGrayColor.cgColor)
	}

	func setupExemplar() {
		let           name = kExemplarRootName
		zone               = Zone.create(within: name, databaseID: .everyoneID)
		zone?.zoneName     = "this is a typical idea, with three [hidden] ideas in its list"
		zone?.parentLink   = kNullLink

		for index in 1...3 {
			let      child = Zone.create(within: name, for: index, databaseID: .everyoneID)
			child.zoneName = "exemplar \(index)"

			zone?.addChild(child)
		}
	}

}
