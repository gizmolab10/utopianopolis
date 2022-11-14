//
//  ZNode.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/17/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

// a node has children, an array of nodes
// each node is an idea, a note or both. UX decoration indicates which
// has a parent, which is a node
// a widget  is a node, whose zone points to widgetZone, whose parent is nil
// a zrecord is a node, whose zone points to itself. need a safety tactic for this. a zone's parent returns parentZone
// a note    is a node, whose note points to itself. a note's parent returns ownerZone
// how about a crumb?

