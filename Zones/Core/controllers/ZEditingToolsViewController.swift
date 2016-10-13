//
//  ZEditingToolsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZEditingToolsViewController: ZViewController {


    @IBOutlet weak var newZoneButton: ZButton!


    @IBAction func newZoneButtonAction(_ button: ZButton) {
        modelManager.addNewZone()
    }
}
