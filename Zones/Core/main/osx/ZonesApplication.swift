//
//  ZonesApplication.swift
//  Zones
//
//  Created by Jonathan Sand on 1/9/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Cocoa


class ZonesApplication: NSApplication {


    override func showHelp(_ sender: Any?) {
        if !gSettingsViewIDs.contains(.Help), let controller = gControllersManager.controllerForID(.settings) as? ZSettingsViewController {
            gSettingsViewIDs.insert(.Help)

            controller.update()
        }
    }
}
