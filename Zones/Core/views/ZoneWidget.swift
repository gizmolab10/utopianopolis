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


    private var       _textWidget:  ZoneTextWidget!
    private var     _childrenView:  ZView!
    private var   childrenWidgets = [ZoneWidget] ()
    let                 toggleDot = ZoneDot ()
    let                   dragDot = ZoneDot ()
    var                widgetZone:  Zone!
    var                widgetFont:  ZFont { return widgetZone.isSelected ? gSelectedWidgetFont : gWidgetFont }
    var               hasChildren:  Bool  { return widgetZone.hasChildren || widgetZone.count > 0 }


    var controllerView: ZView {
        return gControllersManager.controllerForID(.editor)?.view ?? self
    }


    var textWidget: ZoneTextWidget {
        if _textWidget == nil {
            _textWidget = ZoneTextWidget()

            _textWidget.setup()
            addSubview(_textWidget)

            _textWidget.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                make.width.equalTo(200.0)
            }

            snp.makeConstraints { (make: ConstraintMaker) -> Void in
                make.centerY.equalTo(_textWidget).offset(1.5)
                make.size.greaterThanOrEqualTo(_textWidget)
            }
        }

        return _textWidget
    }


    var childrenView: ZView {
        if  _childrenView == nil {
            _childrenView  = ZView()

            _childrenView.zlayer.backgroundColor = ZColor.clear.cgColor

            addSubview(_childrenView)

            _childrenView.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                make.top.bottom.right.equalTo(self)
            }
        }

        return _childrenView
    }


    deinit {
        childrenWidgets.removeAll()

        _childrenView = nil
        _textWidget   = nil
        widgetZone    = nil
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

        clear()
        gWidgetsManager.registerWidget(self)

        if recursing {
            prepareChildren()
            layoutChildren(kind)
        }

        layoutText()
        layoutDots()
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


    func prepareChildren() {
        if !widgetZone.includeChildren {
            for child in childrenWidgets {
                gWidgetsManager.unregisterWidget(child)
            }

            childrenWidgets.removeAll()

            if _childrenView != nil {
                for view in _childrenView.subviews {
                    view.removeFromSuperview()
                }

                _childrenView.removeFromSuperview()

                _childrenView = nil
            }
        } else {
            for (_, child) in childrenWidgets.enumerated() {
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


    func layoutChildren(_ kind: ZSignalKind) {
        if widgetZone.includeChildren {
            var            index = widgetZone.count
            var previous: ZView? = nil

            while index > 0 {
                index                 -= 1 // go backwards down the arrays, constraint making expects it, above
                let childWidget        = childrenWidgets[index]
                childWidget.widgetZone = widgetZone     [index]

                childWidget.layoutInView(childrenView, atIndex: index, recursing: true, kind: kind)
                childWidget.snp.removeConstraints()
                childWidget.snp.makeConstraints { (make: ConstraintMaker) in
                    if previous != nil {
                        make.bottom.equalTo((previous?.snp.top)!)
                    } else {
                        make.bottom.equalTo(childrenView)
                    }

                    if index == 0 {
                        make.top.equalTo(childrenView)
                    }

                    make.left.equalTo(childrenView)
                    make.right.height.lessThanOrEqualTo(childrenView)
                }

                previous = childWidget
            }
        }
    }


    func layoutDots() {
        if !subviews.contains(dragDot) {
            addSubview(dragDot)
        }

        dragDot.innerDot?.snp.removeConstraints()
        dragDot.setupForWidget(self, asToggle: false)
        dragDot.innerDot?.snp.makeConstraints { (make: ConstraintMaker) in
            make.right.equalTo(textWidget.snp.left)
            make.centerY.equalTo(textWidget).offset(1.5)
        }

        if !subviews.contains(toggleDot) {
            addSubview(toggleDot)
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


    var dragTargetFrame: CGRect {
        let isHere = widgetZone == gHere
        let cFrame = convert(childrenView.frame, to: controllerView)
        let  right =                                                   controllerView.bounds .maxX
        let    top = ((!isHere && widgetZone.hasZonesAbove) ? cFrame : controllerView.bounds).maxY
        let bottom =  (!isHere && widgetZone.hasZonesBelow) ? cFrame.minY : 0.0
        let   left =    isHere ? 0.0 : convert(dragDot.innerDot!.frame, to: controllerView).minX
        let result = CGRect(x: left, y: bottom, width: right - left, height: top - bottom)

        return result
    }


    func dragContainsPoint(_ iPoint: CGPoint) -> Bool {
        let rect = dragTargetFrame

        return rect.minX <= iPoint.x && rect.minY <= iPoint.y && rect.maxY >= iPoint.y
    }


    func widgetNearestTo(_ iPoint: CGPoint, in iView: ZView) -> ZoneWidget? {
        if dragContainsPoint(iPoint) && widgetZone.isDescendantOf(gSelectionManager.zoneBeingDragged!) == .none {
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
            let isIndex = gSelectionManager.targetLineIndices?.contains(iIndex!)
            let  isDrop = widgetZone == gSelectionManager.targetDropZone

            if isDrop && isIndex! {
                return true
            }
        }

        return false
    }


    // MARK:- draw
    // MARK:-


    func path(to dragRect: CGRect) -> ZBezierPath? {
        var path: ZBezierPath? = nil

        if  let   dot = toggleDot.innerDot {
            let frame = dot.convert(dot.bounds, to: self)
            let delta = Double(dragRect.midY - frame.midY)
            let  kind = lineKindFor(delta)
            let  rect = rectForLine(to: dragRect, kind: kind)
            path      = self.path(in: rect,      iKind: kind)
        }

        return path
    }


    func drawDragLine() {
        let linePath = path(to:            floatingDropDotRect)
        let  dotPath = ZBezierPath(ovalIn: floatingDropDotRect)

        gDragTargetsColor.setStroke()
        gDragTargetsColor.setFill()
        linePath?.append(dotPath)
        thinStroke(linePath)
        dotPath.fill()
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

        fillColor.setFill()
        strokeColor.setStroke()
        path.stroke()
    }


    func drawLine(to child: ZoneWidget) {
        let  zone = child.widgetZone!
        // draw drag lines above and below (old style)
        let color = isDropIndex(zone.siblingIndex) ? gDragTargetsColor : zone.isBookmark ? gBookmarkColor : gZoneColor
        // comment this back in for only drawing the dot at the end of the drag line
        // let color = zone.isBookmark ? gBookmarkColor : gZoneColor
        let  path = self.path(in: rectForLine(to: child), iKind: lineKindTo(child))

        color.setStroke()
        thinStroke(path)
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

        if self == s.targetDropZone?.widget {
            drawDragLine()
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
