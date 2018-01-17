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


    func displayViewFor(id: ZDetailsViewID) {
        gDetailsViewIDs.insert(id)

        if  let subviews = stackView?.subviews {
            for subview in subviews {
                if  let stackableView = subview as? ZStackableView {
                    stackableView.update()
                }
            }
        }
    }
}
