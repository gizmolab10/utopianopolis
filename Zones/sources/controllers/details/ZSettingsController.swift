//
//  ZSettingsController.swift
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


class ZSettingsController: ZGenericController {


    @IBOutlet var    stackView: NSStackView?
    override  var controllerID: ZControllerID { return .settings }


    func displayViewFor(id: ZSettingsViewID) {
        gSettingsViewIDs.insert(id)

        if  let subviews = stackView?.subviews {
            for subview in subviews {
                if  let stackableView = subview as? ZStackableView {
                    stackableView.update()
                }
            }
        }
    }
}
