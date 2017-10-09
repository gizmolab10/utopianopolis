//
//  TexstField.swift
//  texst
//
//  Created by Jonathan Sand on 10/4/17.
//  Copyright © 2017 Zones. All rights reserved.
//

import Foundation
import AppKit

class TexstField: NSTextField, NSTextFieldDelegate {

    override func textShouldBeginEditing(_ textObject: NSText) -> Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        textInputReport("text field")
        super.keyDown(with: event)
    }
}
