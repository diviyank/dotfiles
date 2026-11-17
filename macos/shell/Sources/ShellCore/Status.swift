import Foundation

public enum Glyph {
    private static func g(_ codepoint: UInt32) -> String {
        String(Character(Unicode.Scalar(codepoint)!))
    }

    public static let logo = g(0xEB4C)
    public static let batteryFull = g(0xE1A4)
    public static let batteryChargingFull = g(0xE1A3)
    public static let batteryBars = [0xEBDC, 0xEBD9, 0xEBE0, 0xEBDD, 0xEBE2, 0xEBD4, 0xEBD2].map(g)
    public static let volumeUp = g(0xE050)
    public static let volumeDown = g(0xE04D)
    public static let volumeMute = g(0xE04E)
    public static let volumeOff = g(0xE04F)
    public static let wifi = g(0xE63E)
    public static let wifiOff = g(0xE648)
    public static let wifi1Bar = g(0xEBE4)
    public static let wifi2Bar = g(0xEBD6)
    public static let wifi3Bar = g(0xEBE1)
    public static let mail = g(0xE159)
    public static let forum = g(0xE8AF)
    public static let power = g(0xE8AC)
    public static let lock = g(0xE897)
    public static let sleep = g(0xF159)
    public static let restart = g(0xF053)
    public static let clearDay = g(0xF157)
    public static let partlyCloudyDay = g(0xF172)
    public static let cloud = g(0xE2BD)
    public static let foggy = g(0xE818)
    public static let rainy = g(0xF176)
    public static let snowy = g(0xE2CD)
    public static let thunderstorm = g(0xEBDB)
    public static let settings = g(0xE8B8)
    public static let skipPrevious = g(0xE045)
    public static let skipNext = g(0xE044)
    public static let playCircle = g(0xE1C4)
    public static let pauseCircle = g(0xE1A2)
    public static let chevronLeft = g(0xE5CB)
    public static let chevronRight = g(0xE5CC)
    public static let musicNote = g(0xE405)
    public static let videocam = g(0xE04B)
    public static let brightness6 = g(0xE3AB)
    public static let calculate = g(0xEA5F)
    public static let palette = g(0xE40A)
    public static let tune = g(0xE429)
    public static let wallpaper = g(0xE1BC)
    public static let shuffle = g(0xE043)
    public static let lightMode = g(0xE518)
    public static let darkMode = g(0xE51C)
    public static let logout = g(0xE9BA)

    static let named: [(String, String)] = [
        ("spa", logo), ("battery_full", batteryFull), ("battery_charging_full", batteryChargingFull),
        ("battery_0_bar", batteryBars[0]), ("battery_1_bar", batteryBars[1]), ("battery_2_bar", batteryBars[2]),
        ("battery_3_bar", batteryBars[3]), ("battery_4_bar", batteryBars[4]), ("battery_5_bar", batteryBars[5]),
        ("battery_6_bar", batteryBars[6]), ("volume_up", volumeUp), ("volume_down", volumeDown),
        ("volume_mute", volumeMute), ("volume_off", volumeOff), ("wifi", wifi), ("wifi_off", wifiOff),
        ("network_wifi_1_bar", wifi1Bar), ("network_wifi_2_bar", wifi2Bar), ("network_wifi_3_bar", wifi3Bar),
        ("mail", mail), ("forum", forum), ("power_settings_new", power), ("lock", lock),
        ("bedtime", sleep), ("restart_alt", restart), ("clear_day", clearDay),
        ("partly_cloudy_day", partlyCloudyDay), ("cloud", cloud), ("foggy", foggy), ("rainy", rainy),
        ("weather_snowy", snowy), ("thunderstorm", thunderstorm), ("settings", settings),
        ("skip_previous", skipPrevious), ("skip_next", skipNext), ("play_circle", playCircle),
        ("pause_circle", pauseCircle), ("chevron_left", chevronLeft), ("chevron_right", chevronRight),
        ("music_note", musicNote), ("videocam", videocam), ("brightness_6", brightness6),
        ("calculate", calculate), ("palette", palette), ("tune", tune), ("wallpaper", wallpaper),
        ("shuffle", shuffle), ("light_mode", lightMode), ("dark_mode", darkMode), ("logout", logout),
    ]
}

public func batteryGlyph(percent: Int, charging: Bool) -> String {
    if percent >= 100 { return charging ? Glyph.batteryChargingFull : Glyph.batteryFull }
    return Glyph.batteryBars[max(0, min(6, percent * 7 / 100))]
}

public func volumeGlyph(percent: Int, muted: Bool) -> String {
    if muted { return Glyph.volumeOff }
    if percent >= 50 { return Glyph.volumeUp }
    return percent > 0 ? Glyph.volumeDown : Glyph.volumeMute
}

public func wifiGlyph(rssi: Int?) -> String {
    guard let rssi else { return Glyph.wifiOff }
    if rssi >= -55 { return Glyph.wifi }
    if rssi >= -67 { return Glyph.wifi3Bar }
    return rssi >= -75 ? Glyph.wifi2Bar : Glyph.wifi1Bar
}

public func parseStatusLabel(_ lsappinfoOutput: String) -> String? {
    guard let range = lsappinfoOutput.range(of: #""label"="(.*?)""#, options: .regularExpression) else { return nil }
    let label = lsappinfoOutput[range].dropFirst(#""label"=""#.count).dropLast()
    return label.isEmpty ? nil : String(label)
}

private let badgeLimit = 99

public func badgeText(_ label: String) -> String {
    guard let count = Int(label), count > badgeLimit else { return label }
    return "\(badgeLimit)+"
}
