//
//  ZoneTextWidget.swift
//  Zones
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
        if  var range = currentEditor()?.selectedRange {
            if  range.length < 1 {
                range.length = 1

                if  range.location > 0 {
                    range.location -= 1
                }
            }
            
            return range
        }
        
        return NSRange()
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
            isEditable             = widgetZone?.isWritableByUseer ?? false
        #endif
    }


    func layoutText(isEditing: Bool = false) {
        gTextManager.updateText(inZone: widgetZone, isEditing: isEditing)
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

                make.centerY.equalTo(view).offset(-verticalTextOffset)
                make   .left.equalTo(view).offset(gGenericOffset.width + 4.0)
                make  .right.lessThanOrEqualTo(view).offset(-29.0)
                make .height.lessThanOrEqualTo(view).offset(-height)
                make  .width.equalTo(width)
            }
        }
    }

    
    func offset(for selectedRange: NSRange, _ iMoveUp: Bool) -> CGFloat? {
        if  let   name = widgetZone?.zoneName {
            let   font = preferredFont
            let offset = name.offset(using: font, for: selectedRange, movingUp: iMoveUp)
            var   rect = name.rectWithFont(font)
            rect       = convert(rect, to: nil)
            
            return rect.origin.x + offset
        }
        
        return nil
    }
    

    @discardableResult override func becomeFirstResponder() -> Bool {
        if  gTextManager.allowAsFirstResponder(self), let zone = widgetZone,
            super.becomeFirstResponder() {  // becomeFirstResponder is called first so delegate methods will be called
            gTextManager.edit(zone)

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

            gTextManager.assign(t, to: widgetZone)
            updateGUI()
        }
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

            zone.color.setStroke()
            path.stroke()
        }
    }
}
