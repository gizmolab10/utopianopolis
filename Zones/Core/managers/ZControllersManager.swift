//
//  ZControllersManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/11/16.
//  Copyright © 2016 Zones. All rights reserved.
//

import Foundation


class ZControllersManager: NSObject {


    var controllersMap: [ZControllerID : ZGenericViewController] = [:]


    func register(_ forController: ZGenericViewController, at: ZControllerID) {
        controllersMap[at] = forController
    }


    func controller(at: ZControllerID) -> ZGenericViewController {
        return controllersMap[at]!
    }
}
