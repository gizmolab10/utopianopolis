//
//  ZLineView.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/7/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//


#if os(OSX)
import AppKit
#elseif os(iOS)
import UIKit
#endif


class ZLineView: ZView {
    
	override func draw(_ iDirtyRect: CGRect) {
        kGridColor.setFill()
		ZBezierPath(rect: iDirtyRect).fill()
    }

}
