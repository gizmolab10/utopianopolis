//
//  ZDetailsController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZDetailsController: ZGenericController {


    @IBOutlet var stackView: NSStackView?


    override func setup() {
        controllerID = .details
    }
    
    
    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        update()
    }


    func update() {
        stackView?.applyToAllSubviews { iView in
            if  let stackableView = iView as? ZStackableView {
                stackableView.update()
            }
        }
    }


    func displayViewFor(ids: [ZDetailsViewID]) {
        for id in ids {
            gDetailsViewIDs.insert(id)
        }

        update()
    }
}
