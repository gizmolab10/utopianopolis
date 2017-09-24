//
//  ZPhoneController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import SnapKit
import UIKit


class ZPhoneController: ZGenericController, UITabBarDelegate {


    override  var           controllerID : ZControllerID { return .main }
    @IBOutlet var editorBottomConstraint : NSLayoutConstraint?
    @IBOutlet var    editorTopConstraint : NSLayoutConstraint?
    var              favoritesAreVisible = true
    var                actionsAreVisible = true


    @IBAction func favoritesVisibilityButtonAction(iButton: UIButton) {
        favoritesAreVisible           = !favoritesAreVisible
        iButton                .title = favoritesAreVisible ? "<" : ">"
        editorTopConstraint?.constant = favoritesAreVisible ? 45.0 : 0.0
    }


    @IBAction func actionsVisibilityButtonAction(iButton: UIButton) {
        actionsAreVisible                 = !actionsAreVisible
        iButton                    .title = actionsAreVisible ? "<" : ">"
        editorBottomConstraint?.constant = actionsAreVisible ? 45.0 : 0.0
    }
}
