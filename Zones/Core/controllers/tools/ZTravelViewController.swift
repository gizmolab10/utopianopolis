//
//  ZTravelViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 11/13/16.
//  Copyright © 2016 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZTravelViewController: ZGenericViewController {


    @IBOutlet weak var storageModeChoiceControl: ZSegmentedControl!


    @IBAction func choiceAction(_ control: ZSegmentedControl) {
        zonesManager.travelAction(ZTravelAction(rawValue: Int(control.selectedSegmentIndex))!)
    }

}
