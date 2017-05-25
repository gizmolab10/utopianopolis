//
//  ZoneWidget.swift
//  Zones
//
//  Created by Jonathan Sand on 10/7/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
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


    let                   dragDot = ZoneDot        ()
    let                 toggleDot = ZoneDot        ()
    let                textWidget = ZoneTextWidget ()
    let              childrenView = ZView          ()
    private var   childrenWidgets = [ZoneWidget]   ()
    var              parentWidget:  ZoneWidget? { return widgetZone.parentZone?.widget }
    var                hasProgeny:  Bool        { return widgetZone.hasProgeny }
    var                widgetFont:  ZFont       { return widgetZone.isSelected ? gSelectedWidgetFont : gWidgetFont }
    var                widgetZone:  Zone!


    deinit {
        childrenWidgets.removeAll()

        widgetZone = nil
    }


    // MARK:- view hierarchy
    // MARK:-


    func addTextView() {
        if !subviews.contains(textWidget) {
            textWidget.setup()
            addSubview(textWidget)
            snp.makeConstraints { (make: ConstraintMaker) -> Void in
                make.centerY.equalTo(textWidget).offset(1.5)
                make.size.greaterThanOrEqualTo(textWidget)
            }
        }
    }


    func addChildrenView() {
        if !subviews.contains(childrenView) {
            insertSubview(childrenView, belowSubview: textWidget)
            childrenView.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                make.left.equalTo(textWidget.snp.right).offset(gDotWidth)
                make.bottom.top.right.equalTo(self)
            }
        }
    }


    func prepareChildrenWidgets() {
        if !widgetZone.exposeChildren {
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


    // MARK:- layout
    // MARK:-


    func layoutInView(_ inView: ZView?, atIndex: Int?, recursing: Bool, kind signalKind: ZSignalKind) {
        if inView != nil && !(inView?.subviews.contains(self))! {
            inView?.addSubview(self)

            if atIndex == nil {
                snp.remakeConstraints { (make: ConstraintMaker) -> Void in
                    make.center.equalTo(inView!)
                }
            }
        }

        gWidgetsManager.registerWidget(self)
        addTextView()
        layoutText()
        layoutDots()
        addChildrenView()

        if recursing {
            prepareChildrenWidgets()
            layoutChildren(signalKind)
        }

        updateConstraints()
    }


    func layoutChildren(_ kind: ZSignalKind) {
        if widgetZone.exposeChildren {
            var                 index = widgetZone.count
            var previous: ZoneWidget? = nil

            while index > 0 {
                index                 -= 1 // go backwards down the arrays, constraint making expects it
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
            make   .left.equalTo(self).offset(gGenericOffset.width)
            make  .right.lessThanOrEqualTo(self).offset(-29.0)
            make .height.lessThanOrEqualTo(self).offset(-gGenericOffset.height)
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


    var hitRect: CGRect? {
        if  let start = dragDot.innerOrigin, let end = toggleDot.innerExtent {
            return CGRect(start: dragDot.convert(start, to: self), end: toggleDot.convert(end, to: self))
        }

        return nil
    }


    var floatingDropDotRect: CGRect {
        var rect = CGRect()

        if !widgetZone.exposeChildren {

                /////////////////////////
                // DOT IS STRAIGHT OUT //
                /////////////////////////

                if  let        dot = toggleDot.innerDot {
                    let     insetX = CGFloat((gDotHeight - gDotWidth) / 2.0)
                    rect           = dot.convert(dot.bounds, to: self).insetBy(dx: insetX, dy: 0.0).offsetBy(dx: gGenericOffset.width, dy: 0.0)
                }
        } else if let      indices = gSelectionManager.dragDropIndices, indices.count > 0 {
            let         firstindex = indices.firstIndex

            if  let       firstDot = dot(at: firstindex) {
                rect               = firstDot.convert(firstDot.bounds, to: self)
                let      lastIndex = indices.lastIndex

                if  indices.count == 1 || lastIndex >= widgetZone.count {

                    ///////////////////////////
                    // DOT IS ABOVE OR BELOW //
                    ///////////////////////////

                    let   relation = gSelectionManager.dragRelation
                    let    isAbove = relation == .above || (asTask && (lastIndex == 0 || relation == .upon))
                    let multiplier = (isAbove ? 1.0 : -1.0) * gVerticalWeight
                    let    gHeight = Double(gGenericOffset.height)
                    let      delta = (gHeight + (gDotHeight * 0.75)) * multiplier
                    rect           = rect.offsetBy(dx: 0.0, dy: CGFloat(delta))

                } else if lastIndex < widgetZone.count, let secondDot = dot(at: lastIndex) {

                    //////////////////
                    // DOT IS TWEEN //
                    //////////////////

                    let secondRect = secondDot.convert(secondDot.bounds, to: self)
                    let      delta = (rect.minY - secondRect.minY) / CGFloat(2.0)
                    rect           = rect.offsetBy(dx: 0.0, dy: -delta)
                }
            }
        }

        return rect
    }


    func lineKind(for delta: Double) -> ZLineKind {
        let threshold = 2.0   * gVerticalWeight
        let  adjusted = delta * gVerticalWeight
        
        if adjusted > threshold {
            return .above
        } else if adjusted < -threshold {
            return .below
        }
        
        return .straight
    }


    func dot(at index: Int) -> ZoneDot? {
        if widgetZone.count == 0 || index >= widgetZone.count || index < 0 {
            return nil
        }

        let target = widgetZone.children[index]

        return target.widget?.dragDot.innerDot
    }


    func dragContainsPoint(_ iPoint: CGPoint) -> Bool {
        let rect = dragHitFrame

        return rect.minX <= iPoint.x && rect.minY <= iPoint.y && rect.maxY >= iPoint.y
    }


    func widgetNearestTo(_ iPoint: CGPoint, in iView: ZView) -> ZoneWidget? {
        if dragContainsPoint(iPoint) && widgetZone.isDescendantOf(gSelectionManager.draggedZone) == .none {
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
        toggleDot.innerDot?         .setNeedsDisplay()
        parentWidget?               .setNeedsDisplay() // sibling lines
        self                        .setNeedsDisplay() // children lines

        for child in childrenWidgets {
            child .dragDot.innerDot?.setNeedsDisplay()
            child                   .setNeedsDisplay() // grandchildren lines
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


    // MARK:- child lines
    // MARK:-


    func lineKind(to dragRect: CGRect) -> ZLineKind? {
        var kind: ZLineKind? = nil
        if  let    toggleDot = toggleDot.innerDot {
            let   toggleRect = toggleDot.convert(toggleDot.bounds,  to: self)
            let        delta = Double(dragRect.midY - toggleRect.midY)
            kind             = lineKind(for: delta)
        }

        return kind
    }


    func lineKind(to widget: ZoneWidget?) -> ZLineKind {
        var kind:    ZLineKind = .straight
        if  let        dragDot = widget?.dragDot.innerDot, widgetZone.count > 1 {
            let       dragRect = dragDot.convert(dragDot.bounds, to: self)
            if  let   dragKind = lineKind(to: dragRect) {
                kind           = dragKind
            }
        }

        return kind
    }


    func lineRect(to dragRect: CGRect, in iView: ZView) -> CGRect? {
        var rect: CGRect? = nil

        if  let kind = lineKind(to: dragRect) {
            rect     = lineRect(to: dragRect, kind: kind)
            rect     = convert (rect!,          to: iView)
        }

        return rect
    }


    func lineRect(to widget: ZoneWidget?) -> CGRect {
        var    frame = CGRect ()
        if  let  dot = widget?.dragDot.innerDot {
            let kind = lineKind(to: widget)
            frame    = dot.convert(dot.bounds, to: self)
            frame    = lineRect(to: frame, kind: kind)
        }

        return frame
    }


    func straightPath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
        if  !isDragLine && widgetZone.count > 1 {
            ZBezierPath(rect: bounds).setClip()
        }

        let path = ZBezierPath()

        path.move(to: CGPoint(x: iRect.minX, y: iRect.midY))
        path.line(to: CGPoint(x: iRect.maxX, y: iRect.midY))

        return path
    }


    func linePath(in iRect: CGRect, kind iKind: ZLineKind?, isDragLine: Bool) -> ZBezierPath {
        if iKind != nil {
            switch iKind! {
            case .straight: return straightPath(in: iRect, isDragLine)
            default:        return   curvedPath(in: iRect, kind: iKind!)
            }
        }

        return ZBezierPath()
    }


    // MARK:- draw
    // MARK:-


    func drawSelectionHighlight() {
        let     thickness = CGFloat(gDotWidth) / 2.5
        var          rect = textWidget.frame.insetBy(dx: -13.0, dy: 0.0)
        rect.size .width += 2.0
        rect.size.height += highlightHeightOffset
        let        radius = min(rect.size.height, rect.size.width) / 2.08 - 1.0
        let         color = widgetZone.isBookmark || widgetZone.isRootOfFavorites ? gBookmarkColor : gZoneColor
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


    func drawDragLine(to dotRect: CGRect, in iView: ZView) {
        if  let rect = lineRect(to: dotRect, in:iView) {
            let kind = lineKind(to: dotRect)
            let path = linePath(in: rect, kind: kind, isDragLine: true)

            thinStroke(path)
        }
    }


    func drawLine(to child: ZoneWidget) {
        let color = child.widgetZone.isBookmark ? gBookmarkColor : gZoneColor
        let  rect = lineRect(to: child)
        let  kind = lineKind(to: child)
        let  path = linePath(in: rect, kind: kind, isDragLine: false)

        color.setStroke()
        thinStroke(path)
    }


    // lines need CHILD dots drawn first.
    // extra pass through hierarchy to do lines

    var childrenPass = false


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        let        isGrabbed = widgetZone.isGrabbed
        textWidget.textColor = isGrabbed ? widgetZone.isBookmark ? gGrabbedBookmarkColor : gGrabbedTextColor : ZColor.black

        if isGrabbed && !widgetZone.isEditing { // && !childrenPass {  CLUE! ... adding this to the logic makes highlight disappear for zones with children shown
            //performance("highlighting \(widgetZone.zoneName ?? "--------")")
            drawSelectionHighlight()
        }

        if widgetZone.exposeChildren {
            if  childrenPass || gSelectionManager.isDragging {
                for child in childrenWidgets { drawLine(to: child) }
            } else {
                dispatchAsyncInForeground {
                    self.childrenPass = true

                    self.setNeedsDisplay()
                }
            }
        }

        childrenPass = false
    }
}
