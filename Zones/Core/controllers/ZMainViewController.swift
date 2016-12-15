//
//  ZMainViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import Cocoa


class ZMainViewController: ZGenericViewController {


    @IBOutlet var searchBoxHeight: NSLayoutConstraint?


    override func identifier() -> ZControllerID { return .main }


    override func awakeFromNib() {
        searchBoxHeight?.constant = 0
    }
}
