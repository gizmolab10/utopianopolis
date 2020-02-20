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
	var crumbZones  : [Zone]       { return crumbsRootZone?.ancestralPath ?? [] }
	var crumbsText  : String       { return kCrumbSeparator + crumbs.joined(separator: kCrumbSeparator) + kCrumbSeparator }

	var indexOfHere : Int? {
		for (index, zone) in crumbZones.enumerated() {
			if  zone == gHere {
				return index
			}
		}

		return nil
	}

	var crumbs: [String] {
		var result = [String]()

		for zone in crumbZones {
			result.append(zone.unwrappedName)

			if !gShowAllBreadcrumbs,
				zone == gHere {
				break
			}
		}

		return result
	}

	var crumbsRootZone: Zone? {
		switch gWorkMode {
			case .noteMode:  return gCurrentEssay?.zone
			case .graphMode: return gSelecting.firstGrab?.crumbRoot
			case .ideaMode:  return gCurrentlyEditingWidget?.widgetZone
			default:         return nil
		}
	}

	var crumbsColor: ZColor {
		var color = gBackgroundColor

		if  crumbDBID == .mineID {
			color = color + gRubberbandColor
		}

		return color.darker(by: 5.0)
	}

	var crumbRanges: [NSRange] {
		var result = [NSRange]()
		let string = crumbsText

		for crumb in crumbs {
			if  let ranges = string.rangesMatching(kCrumbSeparator + crumb + kCrumbSeparator),
				ranges.count > 0 {
				let offset = kCrumbSeparator.length
				var range = ranges[0]
				range.location += offset
				range.length -= offset * 2
				result.append(range)
			}
		}

		return result
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

	func toggleBreadcrumbExtent() {
		gShowAllBreadcrumbs = !gShowAllBreadcrumbs

		gControllers.signalRegarding(.eCrumbs)
	}

}
