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


    @IBOutlet var    nameLabel: ZTextField?
    @IBOutlet var   otherLabel: ZTextField?
    @IBOutlet var  statusLabel: ZTextField?
    @IBOutlet var  traitsLabel: ZTextField?
    @IBOutlet var  recordLabel: ZTextField?
    @IBOutlet var connectLabel: ZTextField?
    var grab: Zone? = nil


    var statusText: [String] {
        var text = [String] ()

        if  let  zone = grab {
            let count = zone.indirectCount

            text.append(zone.isFetched ? "fetched" : "local")

            if zone.parent != nil {
                text.append("p.ref")
            } else if zone.name(from: zone.parentLink) != nil {
                text.append("p.link")
            }

            if zone.showChildren {
                text.append("show")
            }

            if count != 0 {
                text.append("children \(count)")
            }
        }

        return text
    }


    var otherText: [String] {
        var text = [String] ()

        if  let zone = grab {
            let order = Double(Int(zone.order * 100)) / 100.0

            text.append("order \(order)")
        }

//        if let debugView = view.window?.contentView {
//        if let debugView = gEditorController?.editorRootWidget {
        if let debugView = gEditorView {

            text.append("view \(debugView.bounds.size)")
        }

        return text
    }


    var traitsText: [String] {
        var text = [String] ()

        if  let zone = grab {
            let traits = zone.traits

            for type in traits.keys {
                text.append(type.rawValue)
            }
        }

        return text
    }


    override func setup() {
        controllerID = .debug
    }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        if ![.search, .found].contains(iKind) {
            grab               = gSelectionManager.firstGrab
            nameLabel?   .text = grab?.unwrappedName
            recordLabel? .text = grab?.recordName
            otherLabel?  .text =               otherText.joined(separator: ", ")
            statusLabel? .text =              statusText.joined(separator: ", ")
            traitsLabel? .text = "traits: " + traitsText.joined(separator: ", ")
            connectLabel?.text = gCloudUnavailable ? "local only" : "cloud available"
        }
    }
    
}
