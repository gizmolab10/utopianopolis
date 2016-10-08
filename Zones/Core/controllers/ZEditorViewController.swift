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


class ZEditorViewController: ZViewController, ZoneTextFieldDelegate {

    
    @IBOutlet weak var widget: ZoneWidget!

    
    override open func viewDidLoad() {
        super.viewDidLoad()

        self.widget.delegate = self

        modelManager.registerUpdateClosure { (kind) -> (Void) in
            if kind == UpdateKind.data {
                if let name: String = modelManager.selectedZone.zoneName {
                    self.widget.widgetZone = modelManager.selectedZone
                    self.widget.layoutWithText(name)
                }
            }
        }
    }


#if os(OSX)

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        widget.submit()

        return true
    }

#elseif os(iOS)

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        widget.submit()

        return true
    }

#endif

}
