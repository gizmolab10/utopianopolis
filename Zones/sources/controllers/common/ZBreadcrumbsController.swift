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

class ZBreadcrumbsController: ZGenericController {

	@IBOutlet var breadcrumbLabel : ZTextField?
	var breadcrumbs: [String] { return breadcrumbRootZone?.breadcrumbs ?? [] }
	var breadcrumbText: String { return breadcrumbs.joined(separator: " ⇨ ") }

	var breadcrumbsColor: ZColor {
		var color = gBackgroundColor

		if  breadcrumbRootZone?.databaseID == .mineID {
			color = color + gRubberbandColor
		}

		return color.darker(by: 5.0)
	}

	var breadcrumbRootZone: Zone? {
		switch gWorkMode {
			case .graphMode: return gHereMaybe
			default:		 return gCurrentEssay?.zone
		}
	}

	var breadcrumbRects: [CGRect] {
		return []
	}

	func updateBreadcrumbs() {
		breadcrumbLabel?     .text = breadcrumbText
		breadcrumbLabel?.textColor = breadcrumbsColor
	}

}
