//
//  ZoneWindow.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneWindow: ZWindow {


    static var window: ZoneWindow?


    override func awakeFromNib() {
        super.awakeFromNib()

        ZoneWindow.window = self
    }


    #if os(OSX)
    override func keyDown(with event: ZEvent) {
        if !gEditingManager.isEditing && !gEditingManager.handleEvent(event, isWindow: true) {
            super.keyDown(with: event)
        }
    }
    #endif
}
