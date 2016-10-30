//
//  ZSettingsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/29/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZSettingsViewController: ZGenericViewController {


    @IBOutlet weak var flushButton: ZButton!


    @IBAction func genericButtonAction(_ button: ZButton) {
        cloudManager.flush()
    }
}
