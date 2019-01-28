//
//  ZTriangleButton.swift
//  iPhone
//
//  Created by Jonathan Richard Sand on 1/27/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif


class ZTriangleButton : ZButton {
    
    func setState(_ on: Bool) {
        #if os(OSX)
        var image = ZImage(named: kTriangleImageName)
        
        if !on {
            image = (image?.imageRotatedByDegrees(180.0))! as ZImage
        }
        
        self.image = image
        #endif
    }
    
}
