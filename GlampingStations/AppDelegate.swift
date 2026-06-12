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

    // MARK: - Shared Dynamic Colors

    /// Deep trailhead navy / warm off-white - main view background.
    static let primaryBg = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 7/255, green: 20/255, blue: 30/255, alpha: 1)
            : UIColor(red: 246/255, green: 246/255, blue: 240/255, alpha: 1)
    }

    /// Raised surface with a subtle green cast in dark mode.
    static let cardColor = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 17/255, green: 37/255, blue: 43/255, alpha: 1)
            : UIColor(red: 255/255, green: 255/255, blue: 252/255, alpha: 1)
    }

    /// Warm campsite light, cool route teal, and utility copper.
    static let accentGold = UIColor(red: 232/255, green: 178/255, blue: 66/255, alpha: 1)
    static let routeTeal = UIColor(red: 67/255, green: 166/255, blue: 151/255, alpha: 1)
    static let dumpCopper = UIColor(red: 196/255, green: 104/255, blue: 62/255, alpha: 1)

    /// Muted blue-gray / slate — secondary labels
    static let mutedText = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 154/255, green: 174/255, blue: 177/255, alpha: 1)
            : UIColor(red: 91/255, green: 105/255, blue: 105/255, alpha: 1)
    }

    /// White in dark / black in light — primary label text
    static let labelText: UIColor = .label

    /// Subtle input field background
    static let inputBg = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.07)
            : UIColor.black.withAlphaComponent(0.05)
    }

    /// Hairline separator
    static let separatorColor = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.08)
    }

    // MARK: - Shared Appearance Objects

    static var navBarAppearance: UINavigationBarAppearance {
        let a = UINavigationBarAppearance()
        a.configureWithTransparentBackground()
        a.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
        a.backgroundColor = primaryBg.withAlphaComponent(0.72)
        a.shadowColor = separatorColor
        a.titleTextAttributes      = [.foregroundColor: UIColor.label]
        a.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        return a
    }

    static var tabBarAppearance: UITabBarAppearance {
        let a = UITabBarAppearance()
        a.configureWithTransparentBackground()
        a.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
        a.backgroundColor = primaryBg.withAlphaComponent(0.76)
        a.shadowColor = separatorColor
        a.stackedLayoutAppearance.selected.iconColor = accentGold
        a.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accentGold]
        a.stackedLayoutAppearance.normal.iconColor = mutedText
        a.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: mutedText]
        return a
    }

    static var dumpStationImage: UIImage? {
        UIImage(named: "dumpStationGlyph")?.withRenderingMode(.alwaysTemplate)
    }

    static var travelTrailerImage: UIImage? {
        UIImage(named: "travelTrailerGlyph")?.withRenderingMode(.alwaysTemplate)
    }

    static var exploreMapImage: UIImage? {
        UIImage(named: "exploreMapGlyph")?.withRenderingMode(.alwaysTemplate)
    }

    static var routeJourneyImage: UIImage? {
        UIImage(named: "routeJourneyGlyph")?.withRenderingMode(.alwaysTemplate)
    }

    static var mapFilterImage: UIImage? {
        UIImage(named: "mapFilterGlyph")?.withRenderingMode(.alwaysTemplate)
    }

    static var rvSettingsImage: UIImage? {
        UIImage(named: "rvSettingsGlyph")?.withRenderingMode(.alwaysTemplate)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppDelegate.moc = persistentContainer.viewContext
        FirebaseApp.configure()

        // Global appearance proxies
        UINavigationBar.appearance().standardAppearance = AppDelegate.navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = AppDelegate.navBarAppearance
        UINavigationBar.appearance().compactAppearance = AppDelegate.navBarAppearance
        UINavigationBar.appearance().tintColor = AppDelegate.accentGold
        UINavigationBar.appearance().isTranslucent = true

        UITabBar.appearance().standardAppearance = AppDelegate.tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = AppDelegate.tabBarAppearance
        UITabBar.appearance().isTranslucent = true

        // Apply stored appearance preference (default is dark)
        if UserDefaults.standard.object(forKey: AboutViewController.appearanceKey) == nil {
            UserDefaults.standard.set(0, forKey: AboutViewController.appearanceKey)
        }
        AboutViewController.applyStoredAppearance(to: window)

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
