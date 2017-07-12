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


    @IBOutlet var stackView: NSStackView?

    
    override func identifier() -> ZControllerID { return .settings }


    func displayViewFor(id: ZSettingsViewID) {
        let stackableType = ZStackableView.self

        gSettingsViewIDs.insert(id)
        stackView?.applyToAllSubviews { (iView: ZView) in
            let viewType  = type(of: iView)

            if  viewType == stackableType, let stackableView = iView as? ZStackableView {
                stackableView.update()
            }
        }
    }

}
