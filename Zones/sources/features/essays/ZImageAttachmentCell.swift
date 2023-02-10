//
//  ZImageAttachmentCell.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/8/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZImageAttachmentCell : NSTextAttachmentCell {

	var original : NSTextAttachmentCell?

	override var image: NSImage? {
		get {
			return gIsDark ? original?.image?.invertedImage : original?.image
		}

		set {
			original?.image = newValue
		}
	}

}
