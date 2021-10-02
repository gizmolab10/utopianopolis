//
//  ViewController.swift
//  simple
//
//  Created by Jonathan Sand on 9/28/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

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

