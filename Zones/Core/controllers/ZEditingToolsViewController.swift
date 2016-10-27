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


    @IBOutlet weak var    newZoneButton: ZButton!
    @IBOutlet weak var deleteZoneButton: ZButton!


    @IBAction func genericButtonAction(_ button: ZButton) {
        switch button.tag {
        case 0:
            modelManager.addNewZone()
        default:
            modelManager.deleteSelectedZone()
        }
    }
}
