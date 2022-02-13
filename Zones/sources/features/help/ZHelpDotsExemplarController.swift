//
//  ZHelpDotsExemplarController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/16/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CoreData

var gHelpMapView                : ZMapView?                    { return gHelpDotsExemplarController?.helpMapView }
var gHelpHyperlinkColor         : ZColor                       { return gIsDark ? kSystemBlue.lighter(by: 3.0) : kSystemBlue.darker(by: 4.0) }
var gHelpDotsExemplarController : ZHelpDotsExemplarController? { return gControllers.controllerForID(.idHelpDots) as? ZHelpDotsExemplarController }

class ZHelpDotsExemplarController : ZMapController {

	override  var   controllerID : ZControllerID { return .idHelpDots }
	override  var     widgetType : ZWidgetType   { return .tExemplar }
	override  var     isExemplar : Bool          { return true }
	override  var       isBigMap : Bool          { return false }
	override  var       hereZone : Zone?         { return rootZone }
	var                 rootZone : Zone?
	@IBOutlet var       topLabel : ZTextField?
	@IBOutlet var    bottomLabel : ZTextField?
	@IBOutlet var    helpMapView : ZMapView?

	override func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return super.shouldHandle(kind) && (gHelpWindow?.isVisible ?? false)
	}

	override func controllerStartup() {
		controllerSetup(with: helpMapView)
		setupExemplar()

		topLabel?   .font = kLargeHelpFont
		topLabel?   .text = "ALL ideas have a DRAG dot on the left. Many have a REVEAL dot on the right. For example:"
		bottomLabel?.font = kLargeHelpFont
		bottomLabel?.text = "\t• The drag dot (at left) is used to select, deselect and drag the idea\n\t• The reveal dot (at right) is used to show or hide its list, or activate the idea\n\nWhen the cursor hovers over a dot, the fill in color reverses (try the dots above). Dots are often decorated, providing further information about their idea (see below)."
//		mapView?.drawBorder(thickness: 0.5, radius: .zero, color: kDarkGrayColor.cgColor)
		gRelayoutMaps()
	}

	func setupExemplar() {
		let             name = kExemplarRootName
		rootZone             = Zone.create(within: name, databaseID: .everyoneID)
		rootZone?.zoneName   = "this is a typical idea, with three [hidden] ideas in its list"
		rootZone?.color      = kDefaultIdeaColor
		rootZone?.parentLink = kNullLink
		rootZone?.root       = rootZone

		for index in 1...3 {
			let        child = Zone.create(within: name, for: index, databaseID: .everyoneID)
			child  .zoneName = "exemplar \(index)"
			child      .root = rootZone

			rootZone?.addChildNoDuplicate(child)
		}

		rootZone?.expand()
	}

}
