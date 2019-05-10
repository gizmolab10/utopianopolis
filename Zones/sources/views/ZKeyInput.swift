//
//  ZKeyInput.swift
//  iFocus
//
//  Created by Jonathan Sand on 4/28/19.
//  Copyright © 2019 Zones. All rights reserved.
//


import UIKit


class ZKeyInput : UIControl, UIKeyInput {
    
    var hasText: Bool
    override var canBecomeFirstResponder: Bool {return true}

    
    required init?(coder aDecoder: NSCoder) {
        self.hasText = false

        super.init(coder: aDecoder)
    }
    
    
    @discardableResult override func becomeFirstResponder() -> Bool {
        return super.becomeFirstResponder() 
    }
    
    
    func deleteBackward() {}


    public func insertText(_ text: String) {
        gGraphEditor.handleKey(text, flags: ZEventFlags(), isWindow: true)
    }

}
