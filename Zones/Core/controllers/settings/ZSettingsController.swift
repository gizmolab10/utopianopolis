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

    
    override func identifier() -> ZControllerID { return .settings }


    func displayViewFor(id: ZSettingsViewID) {
        let type = ZStackableView.self

        gSettingsViewIDs.insert(id)
        view.applyToAllSubviews { (iView: ZView) in
            if  type(of: iView) == type, let stackView = iView as? ZStackableView {
                stackView.update()
            }
        }
    }

}
