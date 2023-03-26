//
//  SimpleViewController.swift
//  simple
//
//  Created by Jonathan Sand on 9/28/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class SimpleViewController: NSViewController {

	@IBOutlet var input: NSTextField?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
			// Update the view, if already loaded.
        }
    }

	@IBAction func handleTextInput(sender: NSTextField) {
		gSimple?.name = sender.stringValue

		gSave()
	}

}

