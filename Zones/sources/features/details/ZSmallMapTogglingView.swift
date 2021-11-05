//
//  ZSmallMapTogglingView.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/31/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

var gSmallTogglingView: ZSmallMapTogglingView?

class ZSmallMapTogglingView: ZTogglingView {

	@IBOutlet var heightConstraint : NSLayoutConstraint?

	override func awakeFromNib() {
		super.awakeFromNib()
		hideableView?.snp.removeConstraints()

		gSmallTogglingView = self
	}

	override func updateHideableView() {
		if  let            bannerFrame = bannerView?.frame {
			var                      y = bannerFrame.height
			if  let   rootWidgetHeight = gSmallMapController?.rootWidget?.drawnSize.height, !hideHideable {
				let             height = rootWidgetHeight + 8.0
				let               size = CGSize(width: bannerFrame.width, height: height)
				hideableView?   .frame = CGRect(origin: CGPoint(x: 0.0, y: y), size: size)
				y                     += height
			}

			heightConstraint?.constant = y
		}

		super.updateHideableView()
	}

	override func draw(_ iDirtyRect: CGRect) {
		super.draw(iDirtyRect)

		if  !hideHideable, gDebugDraw {
			hideableView?.drawBox(in: self, inset: 1.5, with: ZColor.magenta) // height is zero
			gSmallMapController?.mapView?.debugDraw()
		}
	}

}
