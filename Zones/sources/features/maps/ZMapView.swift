//
//  ZMapView.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/27/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

class ZMapView: ZView {

	@IBOutlet var controller: ZMapController?
	override func menu(for event: ZEvent) -> ZMenu? { return controller?.mapContextualMenu }
	override func updateTrackingAreas() { addTracking(for: bounds) }

}
