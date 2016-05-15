//
//  UViewController.swift
//  Utopia
//
//  Created by Jonathan Sand on 5/12/16.
//  Copyright © 2016 Gizmolab. All rights reserved.
//

import UIKit


class UViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        URealmManager.sharedRealmManager.fire()
        // USessionManager.sharedSessionManager.callDatabase()

    }
}

