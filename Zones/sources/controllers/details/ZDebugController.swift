//
//  ZDebugController.swift
//  Zones
//
//  Created by Jonathan Sand on 1/16/18.
//  Copyright © 2018 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZDebugController: ZGenericController {


    override func setup() {
        controllerID = .debug
    }

    
}
