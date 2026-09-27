import UIKit

/// Rain, snow, or clear — persisted with the save and re-rolled once per new day.
enum Weather: String, Codable {
    case clear, rain, snow

    var hudIcon: String {
        switch self {
        case .clear: return ""
        case .rain: return " 🌧️"
        case .snow: return " ❄️"
        }
    }
}

/// Seasons, weather rolls, and the day/night sky color — ported from app.js's SEASON_NAMES/
/// DAYS_PER_SEASON/SEASON_YARD/SKY_STOPS/rollWeather so the native game keeps the same rhythm as
/// the browser prototype. Pure data/math, no SceneKit dependency, so GameCoordinator can call it
/// from anywhere (the render thread included) without threading concerns.
enum WeatherSystem {
    static let seasonNames = ["Wiosna", "Lato", "Jesień", "Zima"]
    static let daysPerSeason = 7

    static func season(forDay day: Int) -> Int {
        ((day - 1) / daysPerSeason) % 4
    }

    static func seasonName(forDay day: Int) -> String {
        seasonNames[season(forDay: day)]
    }

    private static let seasonYardColors = ["#8bd46a", "#7ec46a", "#c9a24a", "#dfe7ec"]
    private static let winterIndex = 3
    private static let winterSnowColor = "#eef3f6"

    /// The garden/yard tile color for the current season — winter turns white while it's actually
    /// snowing, mirroring SEASON_YARD's optional snowColor.
    static func grassColor(forDay day: Int, weather: Weather) -> UIColor {
        let season = season(forDay: day)
        if season == winterIndex, weather == .snow {
            return UIColor(hex: winterSnowColor)
        }
        return UIColor(hex: seasonYardColors[season])
    }

    /// Mirrors app.js's rollWeather(): called once when a brand new day starts (or a fresh game
    /// boots) — never mid-day, so the weather doesn't flicker minute to minute.
    static func rollWeather(forDay day: Int) -> Weather {
        let season = season(forDay: day)
        let r = Double.random(in: 0..<1)
        switch season {
        case winterIndex: return r < 0.45 ? .snow : .clear
        case 0, 2: return r < 0.4 ? .rain : .clear // wiosna / jesień
        default: return r < 0.15 ? .rain : .clear // lato
        }
    }

    // MARK: - Sky / lighting

    private struct SkyStop { let hour: Double; let color: String }

    private static let skyStops: [SkyStop] = [
        SkyStop(hour: 0, color: "#0b1030"),
        SkyStop(hour: 5, color: "#0b1030"),
        SkyStop(hour: 6.5, color: "#ff9d6c"),
        SkyStop(hour: 8, color: "#8ec9f0"),
        SkyStop(hour: 17, color: "#8ec9f0"),
        SkyStop(hour: 19, color: "#ff8a5c"),
        SkyStop(hour: 21, color: "#2b2560"),
        SkyStop(hour: 23, color: "#0b1030"),
        SkyStop(hour: 24, color: "#0b1030"),
    ]

    static func skyColor(atHour hour: Double) -> UIColor {
        var a = skyStops[0], b = skyStops[skyStops.count - 1]
        for i in 0..<(skyStops.count - 1) where hour >= skyStops[i].hour && hour <= skyStops[i + 1].hour {
            a = skyStops[i]; b = skyStops[i + 1]
            break
        }
        let t = CGFloat((hour - a.hour) / max(0.0001, b.hour - a.hour))
        return UIColor(hex: a.color).lerp(to: UIColor(hex: b.color), t: t)
    }

    /// 0 at full daylight, 1 at full night — used to dim the sun and tint the ambient/fill lights.
    static func nightAmount(atHour hour: Double) -> Double {
        if hour <= 5 || hour >= 21 { return 1 }
        if hour >= 6 && hour <= 19 { return 0 }
        if hour < 6 { return 1 - (hour - 5) }
        return (hour - 19) / 2
    }

    /// Peaks around sunrise/sunset — used to tint the sun light warm/orange at those times.
    static func warmAmount(atHour hour: Double) -> Double {
        let dawn = max(0, 1 - abs(hour - 6.5) / 1.5)
        let dusk = max(0, 1 - abs(hour - 18.5) / 1.5)
        return max(dawn, dusk)
    }
}
