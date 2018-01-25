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


    @IBOutlet var   nameLabel: ZTextField?
    @IBOutlet var  otherLabel: ZTextField?
    @IBOutlet var statusLabel: ZTextField?
    var grab: Zone? = nil


    var statusText: String {
        var text = " "

        if  let zone = grab {
            text.append(zone.alreadyExists ? "F " : "! ")

            if zone.parent != nil {
                text.append("P ")
            } else if zone.name(from: zone.parentLink) != nil {
                text.append("L ")
            }

            if zone.showChildren {
                text.append("S ")
            }
        }

        return text
    }


    var otherText: String {
        var text = ""

        if  let zone = grab {
            text.append("\(zone.order)")
        }

        return text
    }


    override func setup() {
        controllerID = .debug
    }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        if ![.search, .found].contains(iKind) && gReadyState {
            grab              = gSelectionManager.firstGrab
            nameLabel?  .text = grab?.unwrappedName
            otherLabel? .text = otherText
            statusLabel?.text = statusText
        }
    }
    
}
