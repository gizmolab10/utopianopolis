//
//  ZEditorViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZEditorViewController: ZViewController {

    
    @IBOutlet weak var widget: ZoneWidget!

    
    override open func viewDidLoad() {
        super.viewDidLoad()

        modelManager.registerUpdateClosure { (kind) -> (Void) in
            if kind == UpdateKind.data {
                if let name: String = modelManager.selectedZone.zoneName {
                    self.widget.widgetZone = modelManager.selectedZone

                    self.widget.layoutWithText(name)
                    modelManager.resetBadgeCounter()
                }
            }
        }
    }


    @IBAction func tapped(_ sender: AnyObject) {
        widget.submit()
    }
}
