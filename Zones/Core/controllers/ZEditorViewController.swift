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


class ZEditorViewController: ZViewController, ZoneWidgetDelegate {

    
    @IBOutlet weak var label: ZoneWidget!

    
    override open func viewDidLoad() {
        super.viewDidLoad()

        self.label.delegate = self

        modelManager.registerUpdateClosure { (kind) -> (Void) in
            if kind == UpdateKind.data {
                if let name: String = modelManager.selectedZone.zoneName {
                    self.label.text = name
                }
            }
        }
    }


#if os(OSX)

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        modelManager.selectedZone.zoneName = label.text;

        return true
    }

#elseif os(iOS)

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        modelManager.selectedZone.zoneName = label.text;

        return true
    }

#endif

}
