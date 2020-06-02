//
//  ZPermissionController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/2/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

var gPermissionController: ZPermissionController? { return gControllers.controllerForID(.idPermission) as? ZPermissionController }

class ZPermissionController: ZGenericController {

	override var controllerID : ZControllerID { return .idPermission }

}
