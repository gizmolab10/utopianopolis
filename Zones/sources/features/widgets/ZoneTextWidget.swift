//
//  ZoneTextWidget.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

enum ZTextType: Int {
    case prefix
    case name
    case suffix
}

class ZoneTextWidget: ZTextField, ZTextFieldDelegate, ZToolTipper, ZGeneric {

	var                   type = ZTextType.name
	var              drawnSize = CGSize.zero
	var             isHovering = false
    weak var            widget : ZoneWidget?
	override var     debugName : String          { return widgetZone?.zoneName ?? kUnknown }
	var             widgetZone : Zone?           { return widget?.widgetZone }
	var             controller : ZMapController? { return widget?.controller }

    var selectionRange: NSRange {
        var range = gTextEditor.selectedRange

        if  range.length < 1 {
            range.length = 1
            
            if  range.location > 0 {
                range.location -= 1
            }
        }
        
        return range
    }

    func updateTextColor() {
		var color = textColor
		if  gDragging.isDragged(widgetZone) {
			color = gActiveColor
		} else if gIsEssayMode, widgetZone?.isInMainMap ?? true {
			color = kClearColor
		} else if let tColor = widgetZone?.textColor,
				  let cColor = widgetZone?.lighterColor?.invertedBlackAndWhite,
				  let isLinear = widget?.isLinearMode {
			let plain = !gDrawCirclesAroundIdeas
			color = (isLinear || plain) ? tColor : cColor
		} else {
			return
		}

		textColor = color?.accountingForDarkMode
    }

	func controllerSetup(with mapView: ZMapView?) {
		delegate                   = self
        isBordered                 = false
        textAlignment              = .left
        backgroundColor            = kClearColor
        zlayer.backgroundColor     = kClearColor.cgColor
		font                       = widget?.controller?.font ?? gFavoritesFont

        #if os(iOS)
            autocapitalizationType = .none
        #else
            isEditable             = widgetZone?.userCanWrite ?? false
        #endif
    }

	func updateChildrenViewDrawnSizesOfAllAncestors() {
		widgetZone?.traverseAncestors { ancestor in
			if  let widget = ancestor.widget {
				widget.updateLinesViewDrawnSize()
				widget.updateWidgetDrawnSize()

				return .eContinue
			}

			return .eStop
		}
	}

	func updateFrameSize() {
		setFrameSize(drawnSize)
	}

    func updateGUI() {
		updateChildrenViewDrawnSizesOfAllAncestors()
		controller?.layoutForCurrentScrollOffset()
    }

	func setText(_ iText: String?) {
		text = iText

		updateDrawnSize()
	}

	func updateDrawnSize() {
		if  let      f = font,
			let   size = text?.sizeWithFont(f) {
			let   hide = widgetZone?.isFavoritesHere ?? false
			let  width = hide ? .zero : size.width + 6.0
			let height = size.height + (controller?.dotHalfWidth ?? .zero * 0.8)
			drawnSize  = CGSize(width: width, height: height)
		}
	}

	func offset(for selectedRange: NSRange, _ atStart: Bool) -> CGFloat? {
        if  let   name = widgetZone?.unwrappedName,
			let      f = font {
            let offset = name.offset(using: f, for: selectedRange, atStart: atStart)
            var   rect = name.rectWithFont(f)
            rect       = convert(rect, to: nil)
            
            return rect.minX + offset
        }
        
        return nil
    }

	override func mouseDown(with event: ZEvent) {
		if !gRefusesFirstResponder, window == gMainWindow { // ignore mouse down during startup
			gTemporarilySetMouseZone(widgetZone, event.locationInWindow)

			if !becomeFirstResponder() {  // false means did not become first responder
				super.mouseDown(with: event)
			}
		}
	}

    @discardableResult override func becomeFirstResponder() -> Bool {
		printDebug(.dEdit, " BECOME  " + (widgetZone?.unwrappedName ?? kEmpty))

		if !isFirstResponder,
			let zone = widgetZone,
			zone.canEditNow,                 // detect if mouse down inside widget OR key pressed
			super.becomeFirstResponder() {   // becomeFirstResponder is called first here so delegate methods will be called

			if  gIsSearching {
                gExitSearchMode()
			} else if gIsEssayMode {
				gSwapMapAndEssay()
			} else {
				gSetEditIdeaMode()
			}

			gSelecting.ungrabAll(retaining: [zone])
			printDebug(.dEdit, " OFFSET  " + zone.unwrappedName)
			gTextEditor.edit(zone, setOffset: gTextOffset) // recurses back to here if has not already been invoked in call chain

			return true
        }

        return false
	}
	
	func selectCharacter(in range: NSRange) {
        #if os(OSX)
        if  let e = currentEditor() {
            e.selectedRange = range
        }
        #endif
    }

    func alterCase(up: Bool) {
        if  var t = text {
            t = up ? t.uppercased() : t.lowercased()

            gTextEditor.assign(t, to: widgetZone)
            updateGUI()
        }
	}

	func swapWithParent() {
		if  let  zone = widgetZone,
			let saved = text {
			let range = gTextEditor.selectedRange
			zone.swapWithParent {
				gRelayoutMaps() {
					zone.zoneName = saved
					zone.editAndSelect(range: range)
				}
			}
		}
	}

    func extractTitleOrSelectedText(requiresAllOrTitleSelected: Bool = false) -> String? {
        var      extract = text?.extractedTitle

        if  let original = text, gIsEditIdeaMode {
            let    range = gTextEditor.selectedRange
            extract      = original.substring(with: range)

            if  range.length < original.length {
                if !requiresAllOrTitleSelected {
					setText(original.stringBySmartReplacing(range, with: kEmpty))                    
                    gSelecting.ungrabAll()
                } else if range.location != 0 && !original.isLineTitle(enclosing: range) {
                    extract = nil
                }
            }
        }
        
        return extract
    }

	func drawUnderline(_ iDirtyRect: CGRect) {
		if  !isFirstResponder,
			gIsMapOrEditIdeaMode,
			let zone = widgetZone,
			!zone.isGrabbed,
			zone.isTraveller {

			// ////////////////////////////////////////////////// //
			// draw line underneath text indicating it can travel //
			// ////////////////////////////////////////////////// //

			let       deltaX = min(3.0, iDirtyRect.width / 2.0)
			let        inset = CGFloat(0.5)
			var         rect = iDirtyRect.insetBy(dx: deltaX, dy: inset)
			rect.size.height = .zero
			rect   .origin.y = iDirtyRect.maxY - 1.0
			let         path = ZBezierPath(rect: rect)
			path  .lineWidth = 0.4

			zone.color?.setStroke()
			path.stroke()
		}
	}

    override func draw(_ iDirtyRect: CGRect) {
		updateTextColor()
        super.draw(iDirtyRect)
//		drawUnderline(iDirtyRect)
	}

}
