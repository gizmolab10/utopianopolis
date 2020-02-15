//
//  ZBreadcrumbsController.swift
//  Zones
//
//  Created by Jonathan Sand on 2/14/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

// mouse over hit test -> index into breadcrumb strings array
// change the color of the string at that index
// mouse down -> change focus

let gBreadcrumbsController = ZBreadcrumbsController()

class ZBreadcrumbsController: ZGenericController {

	@IBOutlet var crumbsLabel : ZTextField?
	var crumbs:    [String] { return crumbsRootZone?.breadcrumbs ?? [] }
	var crumbsText: String  { return crumbs.joined(separator: " ⇨ ") }

	var crumbsRootZone: Zone? {
		switch gWorkMode {
			case .graphMode: return gHereMaybe
			default:		 return gCurrentEssay?.zone
		}
	}

	var crumbsColor: ZColor {
		var color = gBackgroundColor

		if  crumbsRootZone?.databaseID == .mineID {
			color = color + gRubberbandColor
		}

		return color.darker(by: 5.0)
	}

	var crumbRanges: [NSRange] {
		var result = [NSRange]()

		for crumb in crumbs {
			if  let ranges = crumbsText.rangesMatching(crumb),
				ranges.count > 0 {
				result.append(ranges[0])
			}
		}

		return result
	}

	var crumbRects: [CGRect] {
		var    rects = [CGRect]()

		if  let font = crumbsLabel?.font {
			for range in crumbRanges {
				let rect = crumbsText.rect(using: font, for: range, atStart: true)

				rects.append(rect)
			}
		}

		return rects
	}

	func updateCrumbs(in label: ZTextField?) {
		crumbsLabel      = label
		label?     .text = crumbsText
		label?.textColor = crumbsColor
	}

}
