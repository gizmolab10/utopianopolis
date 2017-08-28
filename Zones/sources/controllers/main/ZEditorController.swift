//
//  ZEditorController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


// adds scrolling and rubberband selection


class ZEditorController: ZGraphController, ZScrollDelegate {


    // MARK:- initialization
    // MARK:-
    

    var        rubberbandPreGrabs = [Zone] ()
    var       priorScrollLocation = CGPoint.zero
    var           rubberbandStart = CGPoint.zero
    override  var            here:  Zone          { return gHere }
    override  var    controllerID:  ZControllerID { return .editor }
    @IBOutlet var         spinner:  ZProgressIndicator?
    @IBOutlet var favoritesWidth :  NSLayoutConstraint?
    @IBOutlet var favoritesHeight:  NSLayoutConstraint?


    // MARK:- gestures
    // MARK:-


    #if os(iOS)
    fileprivate func updateMinZoomScaleForSize(_ size: CGSize) {
        if  let              d = hereWidget, let s = editorView {
            let    heightScale = size.height / d.bounds.height
            let     widthScale = size.width  / d.bounds.width
            let       minScale = min(widthScale, heightScale)
            s.minimumZoomScale = minScale
            s.zoomScale        = minScale
        }
    }


    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateMinZoomScaleForSize(view.bounds.size)
    }
    #endif


    override func layoutForCurrentScrollOffset() {
        if let e = editorView {
            hereWidget.snp.removeConstraints()
            hereWidget.snp.makeConstraints { make in
                make.centerY.equalTo(e).offset(gScrollOffset.y)
                make.centerX.equalTo(e).offset(gScrollOffset.x)
            }
        }
    }


    // MARK:- events
    // MARK:-


    override func movementGestureEvent(_ iGesture: ZGestureRecognizer?) {

        ///////////////////////////////////
        // only called by gesture system //
        ///////////////////////////////////

        if  let  gesture = iGesture as? ZKeyPanGestureRecognizer {
            let location = gesture.location(in: editorView)
            let    state = gesture.state

            if isTextEditing(at: location) {
                restartDragHandling()     // let text editor consume the gesture
            } else if let flags = gesture.modifiers, flags.isOption {
                scrollEvent(move: state == .changed, to: location)
            } else if isDragging {
                dragMaybeStopEvent(iGesture)
            } else if state == .changed { // changed
                rubberbandUpdate(CGRect(start: rubberbandStart, end: location))
            } else if state != .began {   // ended
                rubberbandUpdate(nil)
            } else if let dot = dotsHitTest(location) {
                if dot.isToggle {
                    clickEvent(iGesture)  // no movement
                } else {
                    dragStartEvent(dot, iGesture)
                }
            } else {                      // began
                rubberbandStartEvent(location, iGesture)
            }
        }
    }


    func scrollEvent(move: Bool, to location: CGPoint) {
        if move {
            gScrollOffset   = CGPoint(x: gScrollOffset.x + location.x - priorScrollLocation.x, y: gScrollOffset.y + priorScrollLocation.y - location.y)

            layoutForCurrentScrollOffset()
            editorView?.setNeedsDisplay()
        }

        priorScrollLocation = location
    }


    /////////////////////////////////////////////
    // next four are only called by controller //
    /////////////////////////////////////////////


    func rubberbandStartEvent(_ location: CGPoint, _ iGesture: ZGestureRecognizer?) {
        rubberbandStart = location
        isDragging      = false

        //////////////////////
        // detect SHIFT key //
        //////////////////////

        if let gesture = iGesture, gesture.isShiftDown {
            rubberbandPreGrabs.append(contentsOf: gSelectionManager.currentGrabs)
        } else {
            rubberbandPreGrabs.removeAll()
        }

        note("-- R --")
        gSelectionManager.deselect(retaining: rubberbandPreGrabs)
    }


    // MARK:- internals
    // MARK:-


    override func cleanupAfterDrag() {
        rubberbandStart = CGPoint.zero

        super.cleanupAfterDrag()
    }


    func rubberbandUpdate(_ rect: CGRect?) {
        if  rect == nil {
            editorView?.rubberbandRect = CGRect.zero

            restartDragHandling()
        } else {
            editorView?.rubberbandRect = rect

            gSelectionManager.deselectGrabs(retaining: rubberbandPreGrabs)

            for widget in gWidgetsManager.widgets.values {
                if  let    hitRect = widget.hitRect {
                    let widgetRect = widget.convert(hitRect, to: editorView)

                    if  widgetRect.intersects(rect!) {
                        widget.widgetZone.addToGrab()
                    }
                }
            }

            hereWidget.setNeedsDisplay()
        }

        signalFor(nil, regarding: .preferences)
        editorView?.setNeedsDisplay()
    }


    // MARK:- spinner
    // MARK:-


    override func displayActivity(_ show: Bool) {
        spinner?.isHidden = !show

        if show {
            spinner?.startAnimating()
        } else {
            spinner?.stopAnimating()
        }
    }

}
