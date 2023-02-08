//
//  ZEssayAttachment.swift
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

class ZEssayAttachment : NSTextAttachment {

	var cell : ZEssayAttachmentCell?

	override var attachmentCell: NSTextAttachmentCellProtocol? {
		get {
			if  cell          == nil {
				cell           = ZEssayAttachmentCell()
				cell?.original = super.attachmentCell as? NSTextAttachmentCell
			}

			return cell
		}

		set {
			super.attachmentCell = newValue
		}
	}

}
