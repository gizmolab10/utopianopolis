//
//  ZHelpLineView.swift
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


class ZHelpLineView: ZView {
    
	override func draw(_ iDirtyRect: CGRect) {
		ZBezierPath.fillWithColor(kGridColor, in: iDirtyRect)
    }

}
