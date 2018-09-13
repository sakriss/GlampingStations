//
//  AboutViewController.swift
//  GlampingStations
//
//  Created by Scott Kriss on 9/6/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {

    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var buildLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.versionLabel.text = "   App Version \n   " + version
        }
        
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            self.buildLabel.text = "   Application Build \n   #" + build
        }
    }


}
