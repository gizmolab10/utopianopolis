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
    @IBOutlet var recordLabel: ZTextField?
    var grab: Zone? = nil


    var statusText: [String] {
        var text = [String] ()

        if  let zone = grab {
            let count = zone.fetchableCount

            text.append(zone.isFromCloud ? "cloud" : "local")

            if zone.parent != nil {
                text.append("p.ref")
            } else if zone.name(from: zone.parentLink) != nil {
                text.append("p.link")
            }

            if zone.showChildren {
                text.append("show")
            }

            if count != 0 {
                text.append("fetch \(count)")
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
        if let debugView = gEditorController?.editorRootWidget {
//        if let debugView = gEditorView {

            text.append("view \(debugView.bounds.size)")
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
            recordLabel?.text = grab?.recordName
            otherLabel? .text =  otherText.joined(separator: ", ")
            statusLabel?.text = statusText.joined(separator: ", ")
        }
    }
    
}
