//
//  ZGenericTableController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 5/25/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZGenericTableController: ZGenericController, NSTableViewDelegate, NSTableViewDataSource {

    
    @IBOutlet var tableHeight: NSLayoutConstraint?
    @IBOutlet var   tableView: NSTableView!


    func numberOfRows(in tableView: NSTableView) -> Int { return 1 }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        self.genericTableUpdate()
    }
    

    func genericTableUpdate() {
        tableView.reloadData()
        tableHeight?.constant = CGFloat(numberOfRows(in: tableView)) * tableView.rowHeight
    }
}
