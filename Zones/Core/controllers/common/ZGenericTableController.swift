//
//  ZGenericTableController.swift
//  Zones
//
//  Created by Jonathan Sand on 5/25/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZGenericTableController: ZGenericController, ZTableViewDelegate, ZTableViewDataSource {

    
    @IBOutlet var tableHeight: NSLayoutConstraint?
    @IBOutlet var   tableView: ZTableView!


    override func awakeFromNib() { view.zlayer.backgroundColor = CGColor.clear }
    func numberOfRows(in tableView: ZTableView) -> Int { return 1 }


    func genericTableUpdate() {
        tableView.reloadData()
        tableHeight?.constant = CGFloat(numberOfRows(in: tableView) * 20)
    }
}
