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


enum ActionKind: UInt {
    case add
    case delete
    case moveUp
    case moveDown
}


class ZEditingToolsViewController: ZViewController {


    @IBOutlet weak var    newZoneButton: ZButton!
    @IBOutlet weak var deleteZoneButton: ZButton!


    @IBAction func genericButtonAction(_ button: ZButton) {
        switch ActionKind(rawValue: UInt(button.tag))! {
        case .add:      modelManager.addNewZone();              break
        case .delete:   modelManager.deleteSelectedZone();      break
        case .moveUp:   modelManager.moveSelectedZoneUp(true);  break
        case .moveDown: modelManager.moveSelectedZoneUp(false); break
        }
    }
}
