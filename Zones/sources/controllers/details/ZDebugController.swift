//
//  ZDebugController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 1/16/18.
//  Copyright © 2018 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZDebugController: ZGenericController {


    @IBOutlet var       nameLabel: ZTextField?
    @IBOutlet var      otherLabel: ZTextField?
    @IBOutlet var     statusLabel: ZTextField?
    @IBOutlet var     traitsLabel: ZTextField?
    @IBOutlet var     recordLabel: ZTextField?
    override  var backgroundColor: CGColor       { return gDarkishBackgroundColor }
	override  var    controllerID: ZControllerID { return .idDebug }
    var grab: Zone?


    var statusText: String {
        var text = [String] ()

        if  let  zone = grab {
            let count = zone.indirectCount

            text.append(zone.isFetched ? "fetched" : "local")

            if zone.parent != nil {
                text.append("p.ref")
            } else if zone.recordName(from: zone.parentLink) != nil {
                text.append("p.link")
            }

            if zone.showingChildren {
                text.append("show")
            }

            if count != 0 {
                text.append("children \(count)")
            }
        }

        return text.joined(separator: ", ")
    }


    var otherText: String {
        var text = [String] ()

        if  let zone = grab {
            let order = Double(Int(zone.order * 100)) / 100.0

            text.append("order \(order)")
        }

//        if let debugView = view.window?.contentView {
//        if let debugView = gGraphController?.editorRootWidget {
        if let debugView = gDragView {

            text.append("view \(debugView.bounds.size)")
        }

        return text.joined(separator: ", ")
    }


    var traitsText: String {
        var text = [String] ()

        if  let zone = grab {
            let traits = zone.traits

            for type in traits.keys {
                text.append(type.rawValue)
            }
        }

        return "traits: " + text.joined(separator: ", ")
    }

    
    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        if ![.eSearch, .eFound].contains(iKind) {
            grab                   = gSelecting.firstGrab
            nameLabel?       .text = grab?.unwrappedName
            recordLabel?     .text = grab?   .recordName
            otherLabel?      .text =       otherText
            statusLabel?     .text =      statusText
            traitsLabel?     .text =      traitsText
        }
    }
    
}
