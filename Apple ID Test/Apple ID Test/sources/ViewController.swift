//
//  ViewController.swift
//  useraccounttest
//
//  Created by Jonathan Sand on 4/8/18.
//  Copyright © 2018 Zones. All rights reserved.
//

import Cocoa
import CloudKit


class ViewController: NSViewController {


    @IBOutlet var label: NSTextField?


    override func viewDidLoad() {
        super.viewDidLoad()

        let container = CKContainer(identifier: "iCloud.com.zones.Zones")

        container.accountStatus { (iStatus, iError) in
            FOREGROUND {
                let          statusText = self.text(for: iStatus)
                self.label?.stringValue = "cloud kit account status: \(statusText)"
            }
        }
    }


    func text(for iStatus: CKAccountStatus) -> String {
        switch iStatus {
        case .noAccount:         return "no account"
        case .available:         return "available"
        case .restricted:        return "restricted"
        case .couldNotDetermine: return "could not deterime"
        }
    }

}

