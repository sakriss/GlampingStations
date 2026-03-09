//
//  WeatherService.swift
//  GlampingStations
//
//  Created by Assistant on 2/27/26.
//

import Foundation

struct CurrentWeather: Decodable {
    struct Main: Decodable { let temp: Double }
    struct Weather: Decodable { let description: String, icon: String }
    let main: Main
    let weather: [Weather]
}

final class WeatherService {
    static let shared = WeatherService()
    private let session = URLSession.shared

    // Insert your OpenWeatherMap API key here or inject it from outside.
    // For security, consider loading from a plist or secrets manager.
    private let apiKey: String = "0f5ec87ef07026af5f823330cb81e318"

    func fetchCurrentWeather(lat: Double, lon: Double, units: String = "imperial") async throws -> CurrentWeather {
        guard apiKey.isEmpty == false else { throw URLError(.userAuthenticationRequired) }
        guard var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lon", value: String(lon)),
            URLQueryItem(name: "units", value: units),
            URLQueryItem(name: "appid", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CurrentWeather.self, from: data)
    }
}
