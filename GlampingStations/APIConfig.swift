//
//  APIConfig.swift
//  GlampingStations
//
//  Created by Scott Kriss on 7/23/18.
//  Copyright © 2018 Scott Kriss. All rights reserved.
//

import Foundation

struct APIConfig {
    // Replace these with your actual API configuration
    static let baseURL = "https://api.example.com" // Replace with your actual API endpoint
    static let apiKey = "YOUR_API_KEY" // Replace with your actual API key if needed
    
    // API Endpoints
    static let stationsEndpoint = "/stations"
    static let commentEndpoint = "/comment"
    
    // HTTP Headers
    static let contentType = "application/json"
    static let authorizationHeader = "Authorization"
} 