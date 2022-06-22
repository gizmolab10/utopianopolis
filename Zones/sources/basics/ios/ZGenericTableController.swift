//
//  ZGenericTableController.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/25/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

import Foundation
import UIKit

class ZGenericTableController: ZGenericController, ZTableViewDelegate, ZTableViewDataSource {

    @IBOutlet var      tableHeight: NSLayoutConstraint?
    @IBOutlet var genericTableView: ZTableView!

    func tableView(_ tableView: ZTableView, numberOfRowsInSection section: Int) -> Int { return 1 }
    func numberOfRows(in tableView: ZTableView) -> Int { return tableView(tableView, numberOfRowsInSection: 0) }
    func tableView(_ tableView: ZTableView, cellForRowAt indexPath: IndexPath) -> ZTableCellView { return ZTableCellView() }
    override func handleSignal(_ object: Any?, kind: ZSignalKind) { genericTableUpdate() }

    func genericTableUpdate() {
        genericTableView.reloadData()
        tableHeight?.constant = CGFloat(numberOfRows(in: genericTableView)) * genericTableView.rowHeight
    }
}
