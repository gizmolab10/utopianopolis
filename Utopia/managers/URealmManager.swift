//
//  URealmManager.swift
//  Utopia
//
//  Created by Jonathan Sand on 5/14/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import RealmSwift
import os


public class URealmManager {
    public static let sharedRealmManager = URealmManager();
    // Use them like regular Swift objects
    func fire() -> Void {
        let me = UUtopian()
        me.firstName = "jonathan"
        me.lastName  = "sand"
        print("my name: \(me.name)")

        // Get the default Realm
        let realm = try! Realm()

        // Query Realm for all dogs less than 2 years old
        let folks = realm.objects(UUtopian)
        folks.count // => 0 because no dogs have been added to the Realm yet
        print("now have \(folks.count) folks")

        // Persist your data easily
        try! realm.write {
            realm.add(me)
        }

        // Queries are updated in real-time
        print("now have \(folks.count) folks")

        // Query and update from any thread
        dispatch_async(dispatch_queue_create("background", nil)) {
            let realm = try! Realm()
            let me = realm.objects(UUtopian).last
            try! realm.write {
                me!.lastName = "daSand"
            }

            print("my new name: \(me?.name())")
        }
    }

}
