//
//  ZoneSegmentedControl.swift
//  Seriously
//
//  Created by Jonathan Sand on 9/25/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

import Foundation
import UIKit

class ZoneSegmentedControl : ZSegmentedControl {

    override func awakeFromNib() {
        super.awakeFromNib()

        let image = kSegmentDividerImage
		let  font = UIFont.systemFont(ofSize: 17)

        setDividerImage(image, forLeftSegmentState:   .normal, rightSegmentState:   .normal, barMetrics: .default)
        setDividerImage(image, forLeftSegmentState:   .normal, rightSegmentState: .selected, barMetrics: .default)
        setDividerImage(image, forLeftSegmentState: .selected, rightSegmentState:   .normal, barMetrics: .default)

        setTitleTextAttributes([.font : font], for: .normal)
    }

}
