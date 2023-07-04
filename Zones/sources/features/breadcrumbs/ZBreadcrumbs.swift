//
//  ZBreadcrumbs.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/15/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

let gBreadcrumbs = ZBreadcrumbs()

class ZBreadcrumbs: NSObject {

	var crumbDBID  : ZDatabaseID? { return currentCrumbRoot?.databaseID }
	var crumbZones : ZoneArray    { return currentCrumbRoot?.ancestralPath ?? [] }

	var indexOfHere : Int? {
		for (index, zone) in crumbZones.enumerated() {
			if  zone == gHere {
				return index
			}
		}

		return nil
	}

	var currentCrumbRoot: Zone? {
		if  gIsEssayMode {
			return gEssayView?.selectedZone
		}

		if  gIsSearching {
			return gSearchResultsController?.selectedResult
		}

		switch gWorkMode {
			case .wMapMode:      return gSelecting .firstGrab()?.crumbTipZone
			case .wEssayMode:    return gEssayView?.firstGrabbedNote?.zone ?? gCurrentEssayZone
			case .wEditIdeaMode: return gCurrentlyEditingZone
			default:             return nil
		}
	}

	var crumbsColor: ZColor {
		var color = gAccentColor

		if  crumbDBID == .mineID {
			color = color + gActiveColor
		}

		return color.darker(by: 5.0)
	}

	func nextCrumb(_ out: Bool) -> Zone? {
		let backwards = Array(crumbZones.reversed())
		let increment = out ? 1 : -1

		for (index, crumb) in backwards.enumerated() {
			let newIndex = index + increment

			if  crumb == gHere,
				newIndex >= 0,
				newIndex < backwards.count {
				return backwards[newIndex]
			}
		}

		return nil
	}

}
