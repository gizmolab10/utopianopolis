//
//  ZToggleButton.swift
//  iPhone
//
//  Created by Jonathan Sand on 1/27/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZToggleButton : ZButton {
    var offStateImage: ZImage?
    var  onStateImage: ZImage?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        onStateImage  = kTriangleImage
        offStateImage = kTriangleImage?.imageRotatedByDegrees(180.0)
    }

    func setState(_ on: Bool) {
        #if os(OSX)
        image = on ? onStateImage : offStateImage
        #endif
    }

}
