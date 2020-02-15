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

}
