//
//  ZGenericTableController.swift
//  Zones
//
//  Created by Jonathan Sand on 5/25/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import UIKit


class ZGenericTableController: ZGenericController, ZTableViewDelegate, ZTableViewDataSource {


    @IBOutlet var      tableHeight: NSLayoutConstraint?
    @IBOutlet var genericTableView: UITableView!


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return 1 }
    func numberOfRows(in tableView: UITableView) -> Int { return self.tableView(tableView, numberOfRowsInSection: 0) }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell { return UITableViewCell() }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        self.genericTableUpdate()
    }
    

    func genericTableUpdate() {
        genericTableView.reloadData()
        tableHeight?.constant = CGFloat(numberOfRows(in: genericTableView)) * genericTableView.rowHeight
    }
}
