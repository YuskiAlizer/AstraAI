import Foundation
import CoreLocation

/// Weather Skill — fetches weather data via the Open-Meteo API (no API key needed).
/// Can also use a configurable weather API. Location is only used if the user
/// grants permission; manual city entry is always supported.
final class WeatherSkill: AgentSkill, @unchecked Sendable {

    let id = "weather"
    let name = "Météo"
    let description = "Récupère la météo actuelle et les prévisions. Utilise la localisation si autorisée, ou une ville saisie manuellement."
    let category: SkillCategory = .weather
    let requiredPermissions: [SkillPermission] = [.network]

    private let httpClient: HTTPClient

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "city": .object([
                    "type": .string("string"),
                    "description": .string("Nom de la ville (si non fourni, utilise la localisation si autorisée)")
                ]),
                "latitude": .object([
                    "type": .string("number"),
                    "description": .string("Latitude (alternative à la ville)")
                ]),
                "longitude": .object([
                    "type": .string("number"),
                    "description": .string("Longitude (alternative à la ville)")
                ]),
                "days": .object([
                    "type": .string("number"),
                    "description": .string("Nombre de jours de prévision (défaut: 3)"),
                    "default": .number(3)
                ])
            ])
        ])
    }

    var outputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "current": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "temperature": .number(0),
                        "windspeed": .number(0),
                        "weathercode": .number(0),
                        "description": .string("Description")
                    ])
                ]),
                "forecast": .array([.object([:])])
            ])
        ])
    }

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        let days = input["days"]?.intValue ?? 3

        var lat: Double
        var lon: Double
        var locationName: String

        if let city = input["city"]?.stringValue, !city.isEmpty {
            // Geocode city name
            context.emitEvent(.statusChanged("Recherche de la ville: \(city)..."))
            let coords = try await geocode(city: city)
            lat = coords.latitude
            lon = coords.longitude
            locationName = city
        } else if let latVal = input["latitude"]?.doubleValue,
                  let lonVal = input["longitude"]?.doubleValue {
            lat = latVal
            lon = lonVal
            locationName = "Position (\(lat), \(lon))"
        } else {
            // Try to use device location (requires permission)
            context.emitEvent(.statusChanged("Récupération de la position..."))
            let location = await LocationService.shared.getCurrentLocation()
            if let location {
                lat = location.coordinate.latitude
                lon = location.coordinate.longitude
                locationName = "Ma position"
            } else {
                // Default to Paris if no location available
                lat = 48.8566
                lon = 2.3522
                locationName = "Paris (défaut)"
            }
        }

        context.emitEvent(.statusChanged("Récupération de la météo pour \(locationName)..."))

        // Fetch weather from Open-Meteo (no API key needed)
        let url = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true&daily=temperature_2m_max,temperature_2m_min,weathercode,precipitation_probability_max&timezone=auto&forecast_days=\(days)"

        let response = try await httpClient.get(url)

        guard response.isSuccess else {
            throw SkillError.networkError("Open-Meteo a retourné le code \(response.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
            throw SkillError.networkError("Réponse météo invalide")
        }

        // Parse current weather
        var currentData: [String: JSONValue] = [:]
        if let current = json["current_weather"] as? [String: Any] {
            let temp = current["temperature"] as? Double ?? 0
            let windSpeed = current["windspeed"] as? Double ?? 0
            let weatherCode = current["weathercode"] as? Int ?? 0
            let description = weatherDescription(code: weatherCode)

            currentData = [
                "temperature": .number(temp),
                "windSpeed": .number(windSpeed),
                "weatherCode": .number(Double(weatherCode)),
                "description": .string(description)
            ]
        }

        // Parse daily forecast
        var forecastArray: [JSONValue] = []
        if let daily = json["daily"] as? [String: Any] {
            let dates = daily["time"] as? [String] ?? []
            let tempMax = daily["temperature_2m_max"] as? [Double] ?? []
            let tempMin = daily["temperature_2m_min"] as? [Double] ?? []
            let weatherCodes = daily["weathercode"] as? [Int] ?? []
            let precipProb = daily["precipitation_probability_max"] as? [Double] ?? []

            for i in 0..<min(dates.count, days) {
                forecastArray.append(.object([
                    "date": .string(dates[i]),
                    "tempMax": .number(tempMax[safe: i] ?? 0),
                    "tempMin": .number(tempMin[safe: i] ?? 0),
                    "weatherCode": .number(Double(weatherCodes[safe: i] ?? 0)),
                    "description": .string(weatherDescription(code: weatherCodes[safe: i] ?? 0)),
                    "precipitationProbability": .number(precipProb[safe: i] ?? 0)
                ]))
            }
        }

        let output: JSONValue = .object([
            "location": .string(locationName),
            "latitude": .number(lat),
            "longitude": .number(lon),
            "current": .object(currentData),
            "forecast": .array(forecastArray),
            "days": .number(Double(days))
        ])

        return SkillResult(
            output: output,
            summary: "Météo pour \(locationName): \(currentData["description"]?.stringValue ?? "")"
        )
    }

    // MARK: - Geocoding

    private func geocode(city: String) async throws -> (latitude: Double, longitude: Double) {
        let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        let url = "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedCity)&count=1&language=fr"

        let response = try await httpClient.get(url)

        guard response.isSuccess else {
            throw SkillError.networkError("Géocodage échoué pour: \(city)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first else {
            throw SkillError.custom("Ville introuvable: \(city)")
        }

        let lat = first["latitude"] as? Double ?? 0
        let lon = first["longitude"] as? Double ?? 0

        return (lat, lon)
    }

    // MARK: - Weather Code Description (WMO)

    func weatherDescription(code: Int) -> String {
        switch code {
        case 0: return "Ciel clair"
        case 1: return "Principalement clair"
        case 2: return "Partiellement nuageux"
        case 3: return "Couvert"
        case 45, 48: return "Brouillard"
        case 51, 53, 55: return "Bruine"
        case 56, 57: return "Bruine verglaçante"
        case 61: return "Pluie légère"
        case 63: return "Pluie modérée"
        case 65: return "Pluie forte"
        case 66, 67: return "Pluie verglaçante"
        case 71: return "Neige légère"
        case 73: return "Neige modérée"
        case 75: return "Neige forte"
        case 77: return "Grains de neige"
        case 80, 81: return "Averses de pluie"
        case 82: return "Averses violentes"
        case 85, 86: return "Averses de neige"
        case 95: return "Orage"
        case 96, 99: return "Orage avec grêle"
        default: return "Indéterminé"
        }
    }
}

// MARK: - Location Service

actor LocationService {
    static let shared = LocationService()

    private let manager = CLLocationManager()

    func getCurrentLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            let delegate = LocationDelegate { location in
                continuation.resume(returning: location)
            }
            LocationDelegate.current = delegate
            manager.delegate = delegate

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
                manager.requestLocation()
            default:
                continuation.resume(returning: nil)
            }
        }
    }
}

private final class LocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    static var current: LocationDelegate?
    private let completion: (CLLocation?) -> Void

    init(completion: @escaping (CLLocation?) -> Void) {
        self.completion = completion
        super.init()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        completion(locations.last)
        LocationDelegate.current = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion(nil)
        LocationDelegate.current = nil
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
