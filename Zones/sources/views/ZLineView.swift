//
//  ZLineView.swift
//  iFocus
//
//  Created by Jonathan Sand on 4/7/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation


class ZLineView: ZView {
    
    override func draw(_ iDirtyRect: CGRect) {
        super.draw(iDirtyRect)
        
        kGridColor.setFill()
        
        let path = NSBezierPath(rect: bounds)

        path.fill()
    }

}
