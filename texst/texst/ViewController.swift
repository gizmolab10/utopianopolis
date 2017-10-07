//
//  ViewController.swift
//  texst
//
//  Created by Jonathan Sand on 10/4/17.
//  Copyright © 2017 Zones. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {


    @IBOutlet var innermostView: NSView?
    var tesxtView: TexstField? = nil

    override func awakeFromNib() {
        tesxtView = TexstField(frame: CGRect(x: 0, y: 0, width: 100, height: 22))
        innermostView?.addSubview(tesxtView!)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

