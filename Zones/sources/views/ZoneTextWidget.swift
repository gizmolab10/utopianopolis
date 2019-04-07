//
//  ZoneTextWidget.swift
//  Thoughtful
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


class ZoneTextWidget: ZTextField, ZTextFieldDelegate {


    override var preferredFont : ZFont { return (widget?.isInMain ?? true) ? gWidgetFont : gFavoritesFont }
    var             widgetZone : Zone? { return widget?.widgetZone }
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
            textColor = zone.colorized ? zone.grabbedTextColor : gDefaultTextColor
        }
    }


    override func setup() {
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


    func layoutText(isEditing: Bool = false) {
        gTextEditor.updateText(inZone: widgetZone, isEditing: isEditing)
        layoutTextField()
    }


    func updateGUI() {
        widget?.widgetZone?.deferWrite()
        layoutTextField()
        widget?.setNeedsDisplay()
    }


    func layoutTextField() {
        if  let          view = superview {
            snp.removeConstraints()
            snp.makeConstraints { make in
                let textWidth = text!.widthForFont(preferredFont)
                let  hideText = widgetZone?.onlyShowRevealDot ?? true
                let    height = gGenericOffset.height
                let     width = hideText ? 0.0 : textWidth + 1.0

                make.centerY.equalTo(view)
                make   .left.equalTo(view).offset(gGenericOffset.width + 4.0)
                make  .right.lessThanOrEqualTo(view).offset(-29.0)
                make .height.lessThanOrEqualTo(view).offset(-height)
                make  .width.equalTo(width)
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
    

    @discardableResult override func becomeFirstResponder() -> Bool {
        if  gTextEditor.allowAsFirstResponder(self), let zone = widgetZone,
            super.becomeFirstResponder() {  // becomeFirstResponder is called first so delegate methods will be called
            if  gWorkMode != .graphMode {
                gSearching.exitSearchMode()
            }
            
            gTextEditor.edit(zone)
            
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

        if  let original = text, gIsEditingText {
            let    range = gTextEditor.selectedRange
            extract      = original.substring(with: range)

            if  range.length < original.length {
                if  !requiresAllOrTitleSelected {
                    text = original.stringBySmartReplacing(range, with: "")
                    
                    gSelecting.ungrabAll()
                } else if !original.isLineTitle(within: range) {
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
        if  let  zone = widgetZone {
            textColor = zone.colorized ? zone.color : gDefaultTextColor
        }

        super.draw(dirtyRect)

        if  let zone = widgetZone,
             zone.canTravel,
            !zone.isGrabbed,
            !isFirstResponder {

            ////////////////////////////////////////////////////////
            // draw line underneath text indicating it can travel //
            ////////////////////////////////////////////////////////

            var         rect = dirtyRect.insetBy(dx: 3.0, dy: 0.0)
            rect.size.height = 0.0
            rect.origin.y    = dirtyRect.maxY - 1.0
            let path         = ZBezierPath(rect: rect)
            path  .lineWidth = 0.4

            zone.color?.setStroke()
            path.stroke()
        }
    }
}
