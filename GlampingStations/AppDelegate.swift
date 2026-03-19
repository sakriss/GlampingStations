//
//  AppDelegate.swift
//  GlampingStations
//
//  Created by Scott Kriss on 7/23/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import UIKit
import CoreData
import FirebaseCore

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    static private(set) var moc:NSManagedObjectContext! = nil

    // MARK: - Shared Appearance Objects

    static let primaryBg  = UIColor(red: 10/255, green: 25/255, blue: 47/255, alpha: 1)
    static let accentGold = UIColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1)
    static let mutedText  = UIColor(red: 150/255, green: 165/255, blue: 190/255, alpha: 1)

    static let navBarAppearance: UINavigationBarAppearance = {
        let a = UINavigationBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = primaryBg
        a.titleTextAttributes = [.foregroundColor: UIColor.white]
        a.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        return a
    }()

    static let tabBarAppearance: UITabBarAppearance = {
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = primaryBg
        a.stackedLayoutAppearance.selected.iconColor = accentGold
        a.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accentGold]
        a.stackedLayoutAppearance.normal.iconColor = mutedText
        a.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: mutedText]
        return a
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppDelegate.moc = persistentContainer.viewContext
        FirebaseApp.configure()

        // Global appearance proxies
        UINavigationBar.appearance().standardAppearance = AppDelegate.navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = AppDelegate.navBarAppearance
        UINavigationBar.appearance().compactAppearance = AppDelegate.navBarAppearance
        UINavigationBar.appearance().tintColor = AppDelegate.accentGold
        UINavigationBar.appearance().isTranslucent = false

        UITabBar.appearance().standardAppearance = AppDelegate.tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = AppDelegate.tabBarAppearance
        UITabBar.appearance().isTranslucent = false

        // Start listening for StoreKit 2 transaction updates
        PremiumManager.shared.startTransactionListener()

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        AppDelegate.saveContext()
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "stations")
        container.loadPersistentStores(completionHandler: { (storeDescription:NSPersistentStoreDescription, error) in
            if let error = error as NSError? {
                
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            else {
                storeDescription.shouldInferMappingModelAutomatically = true
                storeDescription.shouldMigrateStoreAutomatically = true
            }
        })
        return container
        
    }()
    
    // MARK: - Core Data Saving support
    
    static func saveContext() {
        
        if let context = AppDelegate.moc {
            
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    let nserror = error as NSError
                    fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                }
            }
        }
    }


}

