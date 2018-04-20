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

        var showPulse = true
        let container = CKContainer(identifier: "iCloud.com.zones.Zones")
        let      fire = { (iTimer: Timer) in
            container.accountStatus { (iStatus, iError) in
                FOREGROUND {
                    let               pulse = showPulse ? "• " : "- "
                    let          statusText = self.text(for: iStatus)
                    self.label?.stringValue = "  cloud kit account status " + pulse + statusText
                    showPulse               = !showPulse
                }
            }
        }

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: fire)
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

