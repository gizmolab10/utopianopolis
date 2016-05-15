//
//  URelationship.swift
//  Utopia
//
//  Created by Jonathan Sand on 5/14/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import RealmSwift


class URelationship: Object {
    let relationships = List <UUtopian> ()

// Specify properties to ignore (Realm won't persist these)
    
//  override static func ignoredProperties() -> [String] {
//    return []
//  }
}
