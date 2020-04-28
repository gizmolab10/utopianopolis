//
//  ZBreadcrumbs.swift
//  Zones
//
//  Created by Jonathan Sand on 2/15/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

let gBreadcrumbs = ZBreadcrumbs()

class ZBreadcrumbs: NSObject {

	var crumbDBID   : ZDatabaseID? { return crumbsRootZone?.databaseID }
	var crumbZones  : ZoneArray    { return crumbsRootZone?.ancestralPath ?? [] }

	var indexOfHere : Int? {
		for (index, zone) in crumbZones.enumerated() {
			if  zone == gHere {
				return index
			}
		}

		return nil
	}

	var crumbsRootZone: Zone? {
		switch gWorkMode {
			case .noteMode:      return gCurrentEssay?.zone
			case .graphMode:     return gSelecting.firstGrab?.crumbRoot
			case .editIdeaMode:  return gCurrentlyEditingWidget?.widgetZone
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
