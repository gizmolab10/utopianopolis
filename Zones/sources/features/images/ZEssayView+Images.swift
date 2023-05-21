//
//  ZEssayView+Images.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/13/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

typealias ZRangedAttachmentArray = [ZRangedAttachment]

struct ZRangedAttachment {
	let glyphRange : NSRange
	let attachment : NSTextAttachment
	var filename   : String? { return attachment.fileWrapper?.filename }

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

extension ZEssayView {

	// MARK: - draw
	// MARK: -

	func drawSelectedImage() {
		let attach = selectedAttachment
		let   rect = rectForResizing(around: attach)
		let  color = (attach == nil) ? kClearColor : gActiveColor

		color.setStroke()
		color.setFill()
		rect?.drawImageResizeDotsAndRubberband()
	}

	func clearImageResizeRubberband() {
		if  resizeDragRect == nil {
			let        path = ZBezierPath(rect: bounds)

			kClearColor.setFill()
			path.fill()           // erase rubberband
		}
	}

	// change cursor to
	// indicate action possible on what's under cursor
	// and possibly display a tool tip

	func updateCursor(for event: ZEvent) {
		let rect = event.locationRect(in: self)

		if  linkHit(at: rect) {
			NSCursor.arrow.set()
		} else if let    dot = dragDotHit(at: rect) {
			if  let     note = dot.note {
				let  grabbed = grabbedNotes.contains(note)
				toolTip      = note.toolTipString(grabbed: grabbed)
			}

			NSCursor.arrow.set()
		} else if let attach = hitTestForAttachment(in: rect) {
			if  let      dot = rectForRangedAttachment(attach)?.hitTestForResizeDot(in: rect) {
				toolTip      = dot.toolTipString

				dot.cursor.set()
			} else {
				toolTip      = gShowToolTips ? "Drag image\r\rClick and drag to move image" : nil

				NSCursor.openHand.set()
			}
		} else {
			toolTip = nil

			NSCursor.iBeam.set()
		}

		setNeedsDisplay()
	}

	// MARK: - mouse events
	// MARK: -

	override func mouseDown(with event: ZEvent) {
		if  !handleClick   (with: event) {
			super.mouseDown(with: event)
			mouseMoved     (with: event)
		}
	}

	override func mouseDragged(with event: ZEvent) {
		super.mouseDragged(with: event)

		if  resizeDot    != nil,
			let     start = resizeDragStart {
			let     flags = event.modifierFlags
			let sizeDelta = CGSize(event.locationRect(in: self).origin - start)

			updateImageResizeRect(for: sizeDelta, flags.hasCommand)
			setNeedsDisplay()
		}
	}

	override func mouseMoved(with event: ZEvent) {
//		super.mouseMoved(with: event) // not call super method: avoid a console warning when a linefeed is selected (sheesh!!!!)
		updateCursor(for: event)
	}

	override func mouseUp(with event: ZEvent) {
		super.mouseUp(with: event)
		save()

		if  let attach = selectedAttachment {
			let  range = attach.glyphRange

			updateSelectedImage()
			updateTextStorageRestoringSelection(range)  // recreate essay after an image is dropped
			asssureSelectionIsVisible()
			setNeedsLayout()
			setNeedsDisplay()

			resizeDragRect = rectForRangedAttachment(attach)
		}
	}

	override func draggingEntered(_ drag: NSDraggingInfo) -> NSDragOperation {
		if  let    board = drag.pasteboardArray,
			let     path = board[0] as? String {
			let fileName = URL(fileURLWithPath: path).lastPathComponent
			printDebug(.dImages, "DROP     \(fileName)")
			dropped.append(fileName)
		}

		return .copy
	}

	override func concludeDragOperation(_ sender: NSDraggingInfo?) {
		super.concludeDragOperation(sender)

		if  let attach = updateSelectedAttachment() {
			setSelectedRange(attach.glyphRange)
		}

		updateTextStorageRestoringSelection(selectedRange)
	}

	// MARK: - rects
	// MARK: -

	func rectForRangedAttachment(_ attach: ZRangedAttachment?) -> CGRect? {
		return attach?.glyphRect(for: textStorage, margin: margin)
	}

	func rectForUnclippedRangedAttachment(_ attach: ZRangedAttachment, orientedFrom direction: ZDirection) -> CGRect? {      // return nil if image is clipped
		if  let image       = attach.attachment.cellImage,
			var rect        = rectForRangedAttachment(attach) {
			if  rect.size.hypotenuse(relativeTo: image.size) > 2.0 {
				let  yDelta = image.size.height - rect.height
				rect  .size = image.size
				switch direction {
					case .topRight,
						 .topLeft,
						 .top: rect.origin.y -= yDelta
					default:   break
				}
			}

			return rect
		}

		return nil
	}

	func hitTestForAttachment(in rect: CGRect) -> ZRangedAttachment? {
		if  let attaches = textStorage?.rangedAttachments {
			for attach in attaches {
				if  let imageRect = rectForRangedAttachment(attach)?.expandedEquallyBy(kEssayImageDotRadius),
					imageRect.intersects(rect) {

					if  let       selected = selectedAttachment?.filename,
						attach.filename   == selected {
						selectedAttachment = attach
					}

					return attach
				}
			}
		}

		return nil
	}

	func rectForResizing(around attach: ZRangedAttachment?) -> CGRect? {
		return resizeDragRect ?? rectForRangedAttachment(attach)
	}

	func updateImageResizeRect(for delta: CGSize, _ COMMAND : Bool) {

		// compute resizeDragRect from delta.width, image rect and corner
		// for COMMAND == false: preserving aspect ratio

		if  let direction = resizeDot,
			let    attach = selectedAttachment,
			let      rect = rectForUnclippedRangedAttachment(attach, orientedFrom: direction) {
			var      size = rect.size
			var    origin = rect.origin
			var  fraction = size.fraction(delta)

			if !COMMAND, direction.isFullResizeCorner { // apply original ratio to fraction
				fraction  = size.fractionPreservingRatio(delta)
			}

			let     wGrow = size.width  * (1.0 - fraction.width)
			let     hGrow = size.height * (1.0 - fraction.height)

			switch direction {
				case .topLeft:     size = size.offsetBy(-wGrow, -hGrow)
				case .bottomLeft:  size = size.offsetBy(-wGrow,  hGrow)
				case .topRight:    size = size.offsetBy( wGrow, -hGrow)
				case .bottomRight: size = size.offsetBy( wGrow,  hGrow)
				case .left:        size = size.offsetBy(-wGrow, .zero)
				case .right:       size = size.offsetBy( wGrow, .zero)
				case .top:         size = size.offsetBy( .zero, -hGrow)
				case .bottom:      size = size.offsetBy( .zero,  hGrow)
			}

			switch direction {
				case .topLeft: origin = origin.offsetBy( wGrow,  hGrow)
				case .topRight,
					 .top:     origin = origin.offsetBy( .zero,  hGrow)
				case .bottomLeft,
					 .left:    origin = origin.offsetBy( wGrow, .zero)
				default:       break
			}

			resizeDragRect = CGRect(origin: origin, size: size)
		}
	}

	// MARK: - image attachment
	// MARK: -

	func clearResizing() {
		selectedAttachment = nil
		resizeDragStart    = nil
		resizeDragRect     = nil
		resizeDot          = nil
	}

	func updateImageInParagraph(containing range: NSRange) {
		clearResizing()                                             // erase image rubberband

		FOREGROUND(after: 0.075) { [self] in
			if  let paragraphRange = textStorage?.string.rangeOfParagraph(for: range) {
				updateSelectedAttachment(for: paragraphRange)
			}

			needsSave = true
		}
	}

	func updateResizeDragRect() {
		resizeDragRect = rectForRangedAttachment(selectedAttachment)    // relocate image rubberband
	}

	@discardableResult func updateSelectedAttachment(for range: NSRange? = nil) -> ZRangedAttachment? {
		let attachmentRange    = range ?? selectedRange
		if  let         attach = textStorage?.rangedAttachment(in: attachmentRange) {
			selectedAttachment = attach
			resizeDragRect     = rectForRangedAttachment(attach)    // relocate image rubberband

			return selectedAttachment
		}

		return nil
	}

	func updateSelectedImage() {
		if  let     size = resizeDragRect?.size,
			let        a = selectedAttachment?.attachment,
			let     name = a.fileWrapper?.preferredFilename,
			let    image = a.cellImage,
			image .size != size,
			let newImage = image.imageResizedTo(size) {
			a .cellImage = newImage

			gFiles.writeImage(newImage, using: name)
		}
	}

}

enum ZDirection : Int {
	case top
	case left
	case right
	case bottom
	case topLeft
	case topRight
	case bottomLeft
	case bottomRight

	var isFullResizeCorner : Bool    { return self == .topLeft || self == .bottomRight }

	var cursor: NSCursor {
		switch self {
			case .top, .bottom: return .resizeUpDown
			case .left, .right: return .resizeLeftRight
			default:            return  kFourArrowsCursor ?? .crosshair
		}
	}

}
