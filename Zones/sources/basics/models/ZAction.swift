//
//  ZAction.swift
//  Seriously
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import CloudKit
import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZAction : ZRecord {

    @objc var action: NSDictionary?
    @objc var  owner: Zone?

    override var cloudProperties: StringsArray {
        return super.cloudProperties + [#keyPath(action), #keyPath(owner)]
    }

}
