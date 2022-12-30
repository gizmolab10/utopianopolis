//
//  ZGenericTableController.swift
//  Seriously
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
    @IBOutlet var genericTableView: ZTableView?

	override func awakeFromNib() {
		super.awakeFromNib()

		if  let                 t = genericTableView {
			t.delegate            = self
			t.dataSource          = self
			tableHeight?.constant = numberOfRows(in: t).float * rowHeight
		}
	}

    func numberOfRows(in tableView: ZTableView) -> Int { return 1 }
	override func handleSignal(_ object: Any?, kind: ZSignalKind) { genericTableUpdate() }
	var rowHeight: CGFloat { return genericTableView?.rowHeight ?? 17.0 }

    func genericTableUpdate() {
        if  let t = genericTableView {
            t.reloadData()
        }
    }

}
