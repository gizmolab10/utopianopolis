//
//  ZImageAttachment.swift
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

typealias ZRangedAttachmentArray = [ZRangedAttachment]
var gIdentity = 0

struct ZRangedAttachment {
	let glyphRange : NSRange
	let attachment : NSTextAttachment
	var identifier = gIdentity
	var filename: String? { return attachment.fileWrapper?.filename }

	func glyphRect(for textStorage: NSTextStorage?, margin: CGFloat) -> CGRect? {
		if  let          managers = textStorage?.layoutManagers, managers.count > 0 {
			let     layoutManager = managers[0] as NSLayoutManager
			let        containers = layoutManager.textContainers
			if  containers .count > 0 {
				let textContainer = containers[0]
				var   actualRange = NSRange()

				layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: &actualRange)

				let          rect = layoutManager.boundingRect(forGlyphRange: actualRange, in: textContainer).offsetBy(dx: margin, dy: margin)

				return rect
			}
		}

		return nil
	}

}

class ZImageAttachment : NSTextAttachment {

	var cell : ZImageAttachmentCell?

	override var attachmentCell: NSTextAttachmentCellProtocol? {
		get {
			if  cell          == nil {
				cell           = ZImageAttachmentCell()
				cell?.original = super.attachmentCell as? NSTextAttachmentCell
			}

			return cell
		}

		set {
			super.attachmentCell = newValue
		}
	}

}
