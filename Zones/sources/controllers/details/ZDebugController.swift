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


    @IBOutlet var       nameLabel: ZTextField?
    @IBOutlet var parentNameLabel: ZTextField?
    @IBOutlet var wasFetchedLabel: ZTextField?


    override func setup() {
        controllerID = .debug
    }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        if ![.search, .found].contains(iKind) && gReadyState {
            let zone = gSelectionManager.firstGrab
            let name = zone.unwrappedName
            let pname = zone.parentZone?.unwrappedName ?? ""
            nameLabel?.text = name
            parentNameLabel?.text = pname
            wasFetchedLabel?.text = zone.alreadyExists ? "fetched" : "dummy"
        }
    }
    
}
