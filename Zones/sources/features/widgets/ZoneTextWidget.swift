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

class ZoneTextWidget: ZTextField, ZTextFieldDelegate, ZTooltips, ZGeneric {

	override var preferredFont : ZFont { return (widget?.type.isBigMap ?? true) ? gWidgetFont : gSmallMapFont }
    var             widgetZone : Zone? { return  widget?.widgetZone }
    weak var            widget : ZoneWidget?
	var                   type = ZTextType.name
	var              drawnSize = CGSize.zero
	var             isHovering = false

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
        if  let  zone = widgetZone {
			textColor = zone.textColor
        }
    }

	func setup() {
		delegate                   = self
        isBordered                 = false
        textAlignment              = .left
        backgroundColor            = kClearColor
        zlayer.backgroundColor     = kClearColor.cgColor
        font                       = preferredFont

        #if os(iOS)
            autocapitalizationType = .none
        #else
            isEditable             = widgetZone?.userCanWrite ?? false
        #endif

		updateTracking()
    }

	var controller: ZMapController? {
		return widget?.controller
	}

	override func menu(for event: ZEvent) -> ZMenu? {
		let         contextualMenu = controller?.ideaContextualMenu
		contextualMenu?.textWidget = self

		return contextualMenu
	}

	open func validateMenuItem(_ menuItem: ZMenuItem) -> Bool {
		return true
	}

	func layoutText(isEditing: Bool = false) {
		gTextEditor.updateText(inZone: widgetZone, isEditing: isEditing)
		applyConstraints()
		updateTooltips()
	}

    func updateGUI() {
		updateTooltips()
        applyConstraints()
        widget?.setNeedsDisplay()
    }

	func setText(_ iText: String?) {
		text = iText

		updateSize()
	}

	func updateSize() {
		if  let        t = text {
			let textSize = t.sizeWithFont(preferredFont)
			let   height = textSize.height + 1.0
			let     hide = widgetZone?.onlyShowRevealDot ?? false                   // only show reveal dot is for small map here
			let    width = hide ? 0.0 : textSize.width + 6.0
			drawnSize    = CGSize(width: width, height: height)
		}
	}

    func applyConstraints() {
		if  let     supe = superview, gAutoLayoutMaps {
			let   offset = (gGenericOffset.height + 13.0) / 3.0                     // add 13/3 to include tiny dot below

			snp.setLabel("<T> \(widgetZone?.zoneName ?? kUnknown)")
			snp.removeConstraints()
            snp.makeConstraints { make in
				make  .width.equalTo(drawnSize.width)								// horizontally, make room for text
                make   .left.equalTo(supe).offset(gGenericOffset.width + 4.0)       //     ",        inset into superview (widget)
				make  .right.lessThanOrEqualTo(supe).offset(-29.0)
				make .height.lessThanOrEqualTo(supe).offset(-offset)		 	    // vertically,   make room for highlight and spacing between siblings
				make.centerY.equalTo(supe)                                          //     ",        center within superview (widget)
            }
        }
    }

	func offset(for selectedRange: NSRange, _ atStart: Bool) -> CGFloat? {
        if  let   name = widgetZone?.unwrappedName {
            let   font = preferredFont
            let offset = name.offset(using: font, for: selectedRange, atStart: atStart)
            var   rect = name.rectWithFont(font)
            rect       = convert(rect, to: nil)
            
            return rect.minX + offset
        }
        
        return nil
    }

	func updateTracking() { addTracking(for: frame) }

	override func mouseEntered(with event: ZEvent) {
		super.mouseEntered(with: event)

		if  isEnabled {
			gHovering.declareHover(self)
		}
	}

	override func mouseMoved(with event: ZEvent) {
		super.mouseMoved(with: event)

		if  isEnabled {
			gHovering.declareHover(self)
		}
	}

	override func mouseExited(with event: ZEvent) {
		super.mouseExited(with: event)
		gHovering.clear()
	}

	override func mouseDown(with event: ZEvent) {
		if !gRefusesFirstResponder { // ignore mouse down during startup
			gTemporarilySetMouseDownLocation(event.locationInWindow.x)
			gTemporarilySetMouseZone(widgetZone)

			if !becomeFirstResponder() {
				super.mouseDown(with: event)
			}
		}
	}

    @discardableResult override func becomeFirstResponder() -> Bool {
		printDebug(.dEdit, " TRY     " + (widgetZone?.unwrappedName ?? kEmpty))

		if !isFirstResponder,
			let zone = widgetZone,
			zone.canEditNow,                 // detect if mouse down inside widget OR key pressed
			super.becomeFirstResponder() {   // becomeFirstResponder is called first so delegate methods will be called

			if  gIsSearchMode {
                gSearching.exitSearchMode()
			} else if gIsEssayMode {
				gControllers.swapMapAndEssay()
			} else {
				gSetEditIdeaMode()
			}

			if  var prior = gSelecting.grabAndNoUI([zone]) {
				prior.appendUnique(item: zone)
				gSelecting.updateWidgetsNeedDisplay(for: prior)
			}

			printDebug(.dEdit, " RESPOND " + zone.unwrappedName)
			gTextEditor.edit(zone, setOffset: gTextOffset)

			return true
        }

        return false
	}
	
	override func selectCharacter(in range: NSRange) {
        #if os(OSX)
        if  let e = currentEditor() {
            e.selectedRange = range
        }
        #endif
    }

    override func alterCase(up: Bool) {
        if  var t = text {
            t = up ? t.uppercased() : t.lowercased()

            gTextEditor.assign(t, to: widgetZone)
            updateGUI()
        }
    }

    func extractTitleOrSelectedText(requiresAllOrTitleSelected: Bool = false) -> String? {
        var      extract = extractedTitle

        if  let original = text, gIsEditIdeaMode {
            let    range = gTextEditor.selectedRange
            extract      = original.substring(with: range)

            if  range.length < original.length {
                if  !requiresAllOrTitleSelected {
					setText(original.stringBySmartReplacing(range, with: kEmpty))                    
                    gSelecting.ungrabAll()
                } else if range.location != 0 && !original.isLineTitle(enclosing: range) {
                    extract = nil
                }
            }
        }
        
        return extract
    }
    
    var extractedTitle: String? {
		var     extract  = text
        
        if  let original = text {
            let substrings = original.components(separatedBy: kHalfLineOfDashes)
            if  substrings.count > 1 {
                extract = substrings[1].spacesStripped
            }
        }
        
        return extract
    }

    override func draw(_ dirtyRect: CGRect) {
        updateTextColor()
        super.draw(dirtyRect)

		var   path : ZBezierPath?
		let  inset = CGFloat(0.5)
		let deltaX = min(3.0, dirtyRect.width / 2.0)

		if  !isFirstResponder,
			gIsMapOrEditIdeaMode,
			let zone = widgetZone,
			!zone.isGrabbed,
			zone.isTraveller {

			// /////////////////////////////////////////////////////
			// draw line underneath text indicating it can travel //
			// /////////////////////////////////////////////////////

			var         rect = dirtyRect.insetBy(dx: deltaX, dy: inset)
			rect.size.height = 0.0
			rect.origin.y    = dirtyRect.maxY - 1.0
			path             = ZBezierPath(rect: rect)
			path? .lineWidth = 0.4

			zone.color?.setStroke()
			path?.stroke()
		}
	}

}
