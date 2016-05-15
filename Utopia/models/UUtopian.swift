//
//  UUtopian.swift
//  Utopia
//
//  Created by Jonathan Sand on 5/14/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import RealmSwift
import os


class UUtopian: Object {
    dynamic var  lastName = ""
    dynamic var firstName = ""
    let     relationships = List <URelationship> ()

    func name() -> String {
        return "\(firstName) \(lastName)"
    }
}
