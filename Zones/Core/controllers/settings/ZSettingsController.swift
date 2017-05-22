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


struct ZSettingsViewID: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let Information = ZSettingsViewID(rawValue: 1 << 0)
    static let Preferences = ZSettingsViewID(rawValue: 1 << 1)
    static let   Favorites = ZSettingsViewID(rawValue: 1 << 2)
    static let       Cloud = ZSettingsViewID(rawValue: 1 << 3)
    static let        Help = ZSettingsViewID(rawValue: 1 << 4)
    static let         All = ZSettingsViewID(rawValue: 0xFFFF)
}


class ZSettingsController: ZGenericController {

    
    override func identifier() -> ZControllerID { return .settings }


    func displayViewFor(id: ZSettingsViewID) {
        let type = ZStackableView.self.className()

        gSettingsViewIDs.insert(id)
        view.applyToAllSubviews { (iView: ZView) in
            if  iView.className == type, let stackView = iView as? ZStackableView {
                stackView.update()
            }
        }
    }

}
