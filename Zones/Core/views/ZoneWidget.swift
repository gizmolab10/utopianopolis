//
//  ZoneWidget.swift
//  Zones
//
//  Created by Jonathan Sand on 10/7/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZLineKind: Int {
    case below    = -1
    case straight =  0
    case above    =  1
}


let dragTarget = false


class ZoneWidget: ZView {


    private var      childrenView = ZView()
    private var   childrenWidgets = [ZoneWidget] ()
    let                textWidget = ZoneTextWidget()
    let                 toggleDot = ZoneDot ()
    let                   dragDot = ZoneDot ()
    var               hasChildren:  Bool   { return widgetZone.hasChildren || widgetZone.count > 0 }
    var                widgetFont:  ZFont  { return widgetZone.isSelected ? gSelectedWidgetFont : gWidgetFont }
    var                widgetZone:  Zone!


    deinit {
        childrenWidgets.removeAll()

        widgetZone = nil
    }


    // MARK:- layout
    // MARK:-


    func layoutInView(_ inView: ZView?, atIndex: Int?, recursing: Bool, kind: ZSignalKind) {
        if inView != nil && !(inView?.subviews.contains(self))! {
            inView?.addSubview(self)

            if atIndex == nil {
                snp.remakeConstraints { (make: ConstraintMaker) -> Void in
                    make.center.equalTo(inView!)
                }
            }
        }

        inView?.zlayer.backgroundColor = ZColor.clear.cgColor
        zlayer        .backgroundColor = ZColor.clear.cgColor

        clear()
        gWidgetsManager.registerWidget(self)
        prepareSubviews()

        if recursing {
            prepareChildren()
            layoutChildren(kind)
        }

        layoutText()
        layoutDots()
    }


    func prepareSubviews() {
        if !subviews.contains(textWidget) {
            textWidget.setup()
            addSubview(textWidget)
            snp.makeConstraints { (make: ConstraintMaker) -> Void in
                make.centerY.equalTo(textWidget).offset(1.5)
                make.size.greaterThanOrEqualTo(textWidget)
            }
        }

        if !subviews.contains(childrenView) {
            childrenView.zlayer.backgroundColor = ZColor.clear.cgColor

            insertSubview(childrenView, belowSubview: textWidget)
            childrenView.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                make.bottom.top.right.equalTo(self)
            }
        }
    }


    func layoutChildren(_ kind: ZSignalKind) {
        if widgetZone.includeChildren {
            var                 index = widgetZone.count
            var previous: ZoneWidget? = nil

            while index > 0 {
                index                 -= 1 // go backwards down the arrays, constraint making expects it, above
                let childWidget        = childrenWidgets[index]
                childWidget.widgetZone = widgetZone     [index]

                childWidget.layoutInView(childrenView, atIndex: index, recursing: true, kind: kind)
                childWidget.snp.removeConstraints()
                childWidget.snp.makeConstraints { (make: ConstraintMaker) in
                    if previous == nil {
                        make.bottom.equalTo(childrenView)
                    } else {
                        make.bottom.equalTo(previous!.snp.top)
                    }

                    if index == 0 {
                        make.top.equalTo(childrenView)
                    }

                    make.left.equalTo(childrenView)
                    make.right.lessThanOrEqualTo(childrenView)
                }
                
                previous = childWidget
            }
        }
    }


    func prepareChildren() {
        if !widgetZone.includeChildren {
            for child in childrenWidgets {
                gWidgetsManager.unregisterWidget(child)
            }

            childrenWidgets.removeAll()

            for view in childrenView.subviews {
                view.removeFromSuperview()
            }
        } else {
            for child in childrenWidgets {
                if !widgetZone.children.contains(child.widgetZone) {
                    gWidgetsManager.unregisterWidget(child)
                    child.removeFromSuperview()

                    if let index = childrenWidgets.index(of: child) {
                        childrenWidgets.remove(at: index)
                    }
                }
            }

            while childrenWidgets.count < widgetZone.count {
                childrenWidgets.append(ZoneWidget())
            }
        }
    }


    func layoutText() {
        textWidget.widget = self
        textWidget.font   = widgetFont

        textWidget.updateText()
        layoutTextField()
    }


    func layoutTextField() {
        textWidget.snp.removeConstraints()
        textWidget.snp.makeConstraints { (make: ConstraintMaker) -> Void in
            let  font = widgetFont
            let width = textWidget.text!.widthForFont(font) + 5.0

            make  .width.equalTo(width)
            make.centerY.equalTo(self).offset(-1.5)
            make   .left.equalTo(self).offset(Double(gGenericOffset.width))
            make  .right.lessThanOrEqualTo(self).offset(-29.0)
            make .height.lessThanOrEqualTo(self).offset(-gGenericOffset.height)

            if hasChildren {
                make.right.equalTo(childrenView.snp.left).offset(-8.0)
            }
        }
    }


    func layoutDots() {
        if !subviews.contains(dragDot) {
            insertSubview(dragDot, belowSubview: textWidget)
        }

        dragDot.innerDot?.snp.removeConstraints()
        dragDot.setupForWidget(self, asToggle: false)
        dragDot.innerDot?.snp.makeConstraints { (make: ConstraintMaker) in
            make.right.equalTo(textWidget.snp.left)
            make.centerY.equalTo(textWidget).offset(1.5)
        }

        if !subviews.contains(toggleDot) {
            insertSubview(toggleDot, belowSubview: textWidget)
        }

        toggleDot.innerDot?.snp.removeConstraints()
        toggleDot.setupForWidget(self, asToggle: true)
        toggleDot.innerDot?.snp.makeConstraints { (make: ConstraintMaker) in
            make.left.equalTo(textWidget.snp.right).offset(-1.0)
            make.right.lessThanOrEqualToSuperview().offset(-1.0)
            make.centerY.equalTo(textWidget).offset(1.5)
        }
    }


    // MARK:- drag
    // MARK:-


    var dragHitFrame: CGRect {
        var result = CGRect()

        if  let   view = gEditorView {
            let isHere = widgetZone == gHere
            let cFrame = convert(childrenView.frame, to: view)
            let  right =                                                   view.bounds .maxX
            let    top = ((!isHere && widgetZone.hasZonesAbove) ? cFrame : view.bounds).maxY
            let bottom =  (!isHere && widgetZone.hasZonesBelow) ? cFrame.minY : 0.0
            let   left =    isHere ? 0.0 : convert(dragDot.innerDot!.frame, to: view).minX
            result     = CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
        }

        return result
    }


    var floatingDropDotRect: CGRect {
        var rect = CGRect()

        if !widgetZone.includeChildren {

                /////////////////////////
                // dot is straight out //
                /////////////////////////

                if  let        dot = toggleDot.innerDot {
                    let     insetX = CGFloat((gDotHeight - gDotWidth) / 2.0)
                    rect           = dot.convert(dot.bounds, to: self).insetBy(dx: insetX, dy: 0.0).offsetBy(dx: gGenericOffset.width, dy: 0.0)
                }
        } else if let      indices = gSelectionManager.dragDropIndices, indices.count > 0 {
            let         firstindex = indices.firstIndex

            if  let       firstDot = dot(at: firstindex) {
                rect               = firstDot.convert(firstDot.bounds, to: self)

                if  indices.count == 1 || indices.lastIndex >= widgetZone.count {

                    ///////////////////////////
                    // dot is above or below //
                    ///////////////////////////

                    let    isAbove = gSelectionManager.dragRelation == .above
                    let multiplier = CGFloat((isAbove ? 1.0 : -1.0) * gVerticalWeight)
                    let      delta = (gGenericOffset.height + CGFloat(gDotHeight * 0.75)) * multiplier
                    rect           = rect.offsetBy(dx: 0.0, dy: delta)

                } else if indices.lastIndex < widgetZone.count, let secondDot = dot(at: indices.lastIndex) {

                    //////////////////
                    // dot is tween //
                    //////////////////

                    let secondRect = secondDot.convert(secondDot.bounds, to: self)
                    let      delta = (rect.minY - secondRect.minY) / CGFloat(2.0)
                    rect           = rect.offsetBy(dx: 0.0, dy: -delta)
                }
            }
        }

        return rect
    }


    func lineKindFor(_ delta: Double) -> ZLineKind {
        let threshold = gDotHeight / 3.0 * gVerticalWeight
        let  adjusted = delta * gVerticalWeight
        
        if adjusted > threshold {
            return .above
        } else if adjusted < -threshold {
            return .below
        }
        
        return .straight
    }


    func dot(at index: Int) -> ZoneDot? {
        if index < widgetZone.count {
            let    target = widgetZone.children[index]

            return target.widget?.dragDot.innerDot
        }

        return nil
    }


    func dragContainsPoint(_ iPoint: CGPoint) -> Bool {
        let rect = dragHitFrame

        return rect.minX <= iPoint.x && rect.minY <= iPoint.y && rect.maxY >= iPoint.y
    }


    func widgetNearestTo(_ iPoint: CGPoint, in iView: ZView) -> ZoneWidget? {
        if dragContainsPoint(iPoint) && widgetZone.isDescendantOf(gSelectionManager.draggedZone!) == .none {
            if widgetZone.showChildren {
                for child in widgetZone.children {
                    if let childWidget = child.widget, let found = childWidget.widgetNearestTo(iPoint, in: self) {
                        return found
                    }
                }
            }

            return self
        }

        return nil
    }


    func displayForDrag() {
        toggleDot        .innerDot?.setNeedsDisplay()
        self                       .setNeedsDisplay()

        for child in childrenWidgets {
            child.dragDot.innerDot?.setNeedsDisplay()
            child                  .setNeedsDisplay()
        }
    }


    func isDropIndex(_ iIndex: Int?) -> Bool {
        if  iIndex != nil {
            let isIndex = gSelectionManager.dragDropIndices?.contains(iIndex!)
            let  isDrop = widgetZone == gSelectionManager.dragDropZone

            if isDrop && isIndex! {
                return true
            }
        }

        return false
    }


    // MARK:- draw
    // MARK:-


    func path(in iRect: CGRect, iKind: ZLineKind) -> ZBezierPath {
        switch iKind {
        case .straight: return straightPathFor(iRect)
        default:        return   curvedPathFor(iRect, iKind: iKind)
        }
    }


    func path(to dragRect: CGRect, in iView: ZView) -> ZBezierPath? {
        var linePath: ZBezierPath? = nil

        if  let   dot = toggleDot.innerDot {
            let frame = dot.convert(dot.bounds,     to: self)
            let delta = Double(dragRect.midY - frame.midY)
            let  kind = lineKindFor(delta)
            var  rect = rectForLine(to: dragRect, kind: kind)
            rect      = convert(rect,               to: iView)
            linePath  = path(in: rect,           iKind: kind)
        }

        return linePath
    }


    func lineKindTo(_ widget: ZoneWidget?) -> ZLineKind {
        if  let           dragDot = widget?.dragDot.innerDot, widgetZone.count > 1 {
            let    dragDotCenterY =    dragDot.convert(   dragDot.bounds, to: self).center.y
            let textWidgetCenterY = textWidget.convert(textWidget.bounds, to: self).center.y
            let             delta = Double(dragDotCenterY - textWidgetCenterY)

            return lineKindFor(delta)
        }

        return .straight
    }


    func rectForLine(to rightWidget: ZoneWidget?) -> CGRect {
        var    frame = CGRect ()

        if  let  dot = rightWidget?.dragDot.innerDot {
            let kind = lineKindTo(rightWidget)
            frame    = dot.convert(dot.bounds, to: self)
            frame    = rectForLine(to: frame, kind: kind)
        }

        return frame
    }


    func drawSelectionHighlight() {
        let     thickness = CGFloat(gDotWidth) / 2.5
        var          rect = textWidget.frame.insetBy(dx: -13.0, dy: 0.0)
        rect.size .width += 2.0
        rect.size.height += highlightHeightOffset
        let        radius = min(rect.size.height, rect.size.width) / 2.08 - 1.0
        let         color = widgetZone.isBookmark ? gBookmarkColor : gZoneColor
        let     fillColor = color.withAlphaComponent(0.02)
        let   strokeColor = color.withAlphaComponent(0.2)
        let          path = ZBezierPath(roundedRect: rect, cornerRadius: radius)
        path   .lineWidth = thickness
        path    .flatness = 0.0001

        strokeColor.setStroke()
        fillColor.setFill()
        path.stroke()
        path.fill()
    }


    func drawLine(to child: ZoneWidget) {
        let  zone = child.widgetZone!
        let color = zone.isBookmark ? gBookmarkColor : gZoneColor
        let  rect = rectForLine(to: child)
        let  kind = lineKindTo(child)
        let  line = path(in: rect, iKind: kind)

        color.setStroke()
        thinStroke(line)
    }


    // lines need CHILD dots drawn first.
    // extra pass through hierarchy to do lines

    var childrenPass = false


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        let                s = gSelectionManager
        let        isGrabbed = widgetZone.isGrabbed
        textWidget.textColor = isGrabbed ? widgetZone.isBookmark ? gGrabbedBookmarkColor : gGrabbedTextColor : ZColor.black

        if isGrabbed && !widgetZone.isEditing {
            drawSelectionHighlight()
        }

        if widgetZone.includeChildren {
            if  childrenPass || s.isDragging {
                childrenPass = false

                for child in childrenWidgets { drawLine(to: child) }
            } else {
                dispatchAsyncInForeground {
                    self.childrenPass = true

                    self.setNeedsDisplay()
                }
            }
        }
    }
}
