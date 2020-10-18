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

	override var preferredFont : ZFont { return (widget?.type.isMap ?? true) ? gWidgetFont : gFavoritesFont }
    var             widgetZone : Zone? { return  widget?.widgetZone }
    weak var            widget : ZoneWidget?
    var                   type = ZTextType.name

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
    }

	var controller: ZMapController? {
		return widget?.controller
	}

	override func menu(for event: NSEvent) -> NSMenu? {
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
		widget?.widgetZone?.needWrite()
    }

    func applyConstraints() {
        if  let container = superview {
			let    height = ((gGenericOffset.height - 2.0) / 3.0) + 5.0              // add 5 to include tiny dot below
			let  hideText = widgetZone?.onlyShowRevealDot ?? true
			let textWidth = text!.widthForFont(preferredFont)
			let     width = hideText ? 0.0 : textWidth + 1.0

			snp.setLabel("<t> \(widgetZone?.zoneName ?? "unknown")")
			snp.removeConstraints()
            snp.makeConstraints { make in
				make  .right.lessThanOrEqualTo(container).offset(-29.0)
				make .height.lessThanOrEqualTo(container).offset(-height)		 	 // vertically,   make room for highlight and push siblings apart
                make.centerY.equalTo(container)                                      //     ",        center within container (widget)
                make   .left.equalTo(container).offset(gGenericOffset.width + 4.0)   // horizontally, inset into        "
                make  .width.equalTo(width)										     //     ",        make room for text
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

	override func mouseDown(with event: NSEvent) {
		if !gRefusesFirstResponder { // ignore mouse down during startup
			gTemporarilySetMouseDownLocation(event.locationInWindow.x)
			gTemporarilySetMouseZone(widgetZone)

			if !becomeFirstResponder() {
				super.mouseDown(with: event)
			}
		}
	}

    @discardableResult override func becomeFirstResponder() -> Bool {
		printDebug(.dEdit, " TRY     " + (widgetZone?.unwrappedName ?? ""))

		if !isFirstResponder,
			let zone = widgetZone,
			zone.canEditNow,                 // detect if mouse down inside widget OR key pressed
			super.becomeFirstResponder() {   // becomeFirstResponder is called first so delegate methods will be called

			if !gIsMapOrEditIdeaMode {
                gSearching.exitSearchMode()
            }

			if  var prior = gSelecting.primitiveGrab([zone]) {
				prior.appendUnique(contentsOf: [zone])
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
                    text = original.stringBySmartReplacing(range, with: "")
                    
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
                extract = substrings[1].stripped
            }
        }
        
        return extract
    }

    override func draw(_ dirtyRect: CGRect) {
        updateTextColor()
        super.draw(dirtyRect)

		// /////////////////////////////////////////////////////
		// draw line underneath text indicating it can travel //
		// /////////////////////////////////////////////////////

        if  let zone = widgetZone,
             zone.canTravel,
            !zone.isGrabbed,
            !isFirstResponder,
			gIsMapOrEditIdeaMode {

			let       deltaX = min(3.0, dirtyRect.width / 2.0)
            var         rect = dirtyRect.insetBy(dx: deltaX, dy: 0.0)
            rect.size.height = 0.0
            rect.origin.y    = dirtyRect.maxY - 1.0
            let path         = ZBezierPath(rect: rect)
            path  .lineWidth = 0.4

            zone.color?.setStroke()
            path.stroke()
        }
    }

}
