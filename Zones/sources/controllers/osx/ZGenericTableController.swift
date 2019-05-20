//
//  ZGenericTableController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 5/25/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import Cocoa


class ZGenericTableController: ZGenericController, NSTableViewDelegate, NSTableViewDataSource {

    
    @IBOutlet var tableHeight: NSLayoutConstraint?
    @IBOutlet var genericTableView: NSTableView?


    func numberOfRows(in tableView: NSTableView) -> Int { return 1 }


    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        self.genericTableUpdate()
    }
    

    func genericTableUpdate() {
        if let t = genericTableView {
            t.reloadData()
            tableHeight?.constant = CGFloat(numberOfRows(in: t)) * t.rowHeight
        }
    }
}
