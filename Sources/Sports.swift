import AppKit

/// A competition the 🏆 strip can follow.
struct Competition {
    enum Source { case espn(String), espnRacing(String), motoGP }
    let id: String
    /// Short tag drawn on the Touch Bar.
    let tag: String
    let name: String
    let group: String
    let source: Source
    let color: UInt32

    var nsColor: NSColor {
        NSColor(calibratedRed: CGFloat(color >> 16 & 0xFF) / 255, green: CGFloat(color >> 8 & 0xFF) / 255,
                blue: CGFloat(color & 0xFF) / 255, alpha: 1)
    }
    var isRacing: Bool { if case .espn = source { return false }; return true }
    /// US leagues list the away team first; football lists the home team first.
    var awayFirst: Bool { if case .espn(let p) = source { return !p.hasPrefix("soccer/") }; return false }

    static let all: [Competition] = [
        .init(id: "epl", tag: "EPL", name: "Premier League", group: "Football", source: .espn("soccer/eng.1"), color: 0xB46CFF),
        .init(id: "laliga", tag: "LALIGA", name: "La Liga", group: "Football", source: .espn("soccer/esp.1"), color: 0xFF6B5B),
        .init(id: "seriea", tag: "SERIE A", name: "Serie A", group: "Football", source: .espn("soccer/ita.1"), color: 0x4DA3FF),
        .init(id: "bundesliga", tag: "BUNDESLIGA", name: "Bundesliga", group: "Football", source: .espn("soccer/ger.1"), color: 0xFF4D4D),
        .init(id: "ligue1", tag: "LIGUE 1", name: "Ligue 1", group: "Football", source: .espn("soccer/fra.1"), color: 0xD7F25A),
        .init(id: "ucl", tag: "UCL", name: "UEFA Champions League", group: "Football", source: .espn("soccer/uefa.champions"), color: 0x5B8CFF),
        .init(id: "uel", tag: "UEL", name: "UEFA Europa League", group: "Football", source: .espn("soccer/uefa.europa"), color: 0xFF9A3D),
        .init(id: "uecl", tag: "UECL", name: "UEFA Conference League", group: "Football", source: .espn("soccer/uefa.europa.conf"), color: 0x3DDC84),
        .init(id: "j1", tag: "J1", name: "J1 League", group: "Football", source: .espn("soccer/jpn.1"), color: 0xFF5C5C),
        .init(id: "acl", tag: "ACL ELITE", name: "AFC Champions League Elite", group: "Football", source: .espn("soccer/afc.champions"), color: 0x2EC4B6),
        .init(id: "acl2", tag: "ACL TWO", name: "AFC Champions League Two", group: "Football", source: .espn("soccer/afc.cup"), color: 0x8AD1C2),
        .init(id: "nba", tag: "NBA", name: "NBA", group: "US sports", source: .espn("basketball/nba"), color: 0xFF7A45),
        .init(id: "nfl", tag: "NFL", name: "NFL", group: "US sports", source: .espn("football/nfl"), color: 0x6FA8FF),
        .init(id: "nhl", tag: "NHL", name: "NHL", group: "US sports", source: .espn("hockey/nhl"), color: 0xCFD8E3),
        .init(id: "mlb", tag: "MLB", name: "MLB", group: "US sports", source: .espn("baseball/mlb"), color: 0xFF5C7A),
        .init(id: "f1", tag: "F1", name: "Formula 1", group: "Motorsport", source: .espnRacing("racing/f1"), color: 0xFF3B30),
        .init(id: "motogp", tag: "MOTOGP", name: "MotoGP", group: "Motorsport", source: .motoGP, color: 0xFF8C1A),
        .init(id: "nascar", tag: "NASCAR", name: "NASCAR Cup Series", group: "Motorsport", source: .espnRacing("racing/nascar-premier"), color: 0xFFD23F),
    ]
    static let defaultIDs = ["epl", "ucl", "nba", "f1", "motogp"]
    static func find(_ id: String) -> Competition? { all.first { $0.id == id } }
}

struct SportsEvent {
    enum State { case pre, live, post }
    enum Kind {
        /// Teams in display order (see Competition.awayFirst).
        case match(left: (String, String?), right: (String, String?))
        /// A race: finished ones carry the podium.
        case race(title: String, podium: [String])
    }
    let comp: Competition
    let kind: Kind
    let state: State
    let date: Date
    /// "FT", "45'", "Q3 5:12", "Final/OT"…
    let detail: String
    let link: URL?
}

enum SportsFetch {
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    /// ESPN writes dates like 2026-11-08T14:00Z (no seconds).
    static func date(_ s: String?) -> Date {
        guard let s else { return .distantPast }
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mmX"
        return f.date(from: s) ?? .distantPast
    }

    static func state(_ s: String?) -> SportsEvent.State {
        switch s { case "in": return .live; case "post": return .post; default: return .pre }
    }

    static func link(_ e: [String: Any]) -> URL? {
        ((e["links"] as? [[String: Any]])?.first?["href"] as? String).flatMap(URL.init(string:))
    }

    /// Team sports from ESPN's scoreboard (the current round or day).
    static func parseTeams(_ j: [String: Any], _ comp: Competition) -> [SportsEvent] {
        ((j["events"] as? [[String: Any]]) ?? []).compactMap { e in
            guard let c = (e["competitions"] as? [[String: Any]])?.first,
                  let teams = c["competitors"] as? [[String: Any]], teams.count == 2 else { return nil }
            let status = (e["status"] as? [String: Any])?["type"] as? [String: Any]
            let st = state(status?["state"] as? String)
            func side(_ which: String) -> (String, String?) {
                let t = teams.first { $0["homeAway"] as? String == which } ?? [:]
                let team = t["team"] as? [String: Any]
                let name = team?["abbreviation"] as? String ?? team?["shortDisplayName"] as? String ?? "?"
                return (name, st == .pre ? nil : t["score"] as? String)
            }
            let home = side("home"), away = side("away")
            return SportsEvent(comp: comp, kind: comp.awayFirst ? .match(left: away, right: home) : .match(left: home, right: away),
                               state: st, date: date(e["date"] as? String),
                               detail: status?["shortDetail"] as? String ?? "", link: link(e))
        }
    }

    /// Racing from ESPN: the last finished race's podium and the next race.
    static func parseRacing(_ j: [String: Any], _ comp: Competition) -> [SportsEvent] {
        let events = ((j["events"] as? [[String: Any]]) ?? []).sorted { date($0["date"] as? String) < date($1["date"] as? String) }
        func race(_ e: [String: Any]) -> [String: Any]? {
            let comps = (e["competitions"] as? [[String: Any]]) ?? []
            return comps.last { (($0["type"] as? [String: Any])?["abbreviation"] as? String) == "Race" } ?? comps.last
        }
        func title(_ e: [String: Any]) -> String { shortTitle(e["shortName"] as? String ?? e["name"] as? String ?? comp.name) }
        var out: [SportsEvent] = []
        if let last = events.last(where: { state((($0["status"] as? [String: Any])?["type"] as? [String: Any])?["state"] as? String) == .post }),
           let r = race(last) {
            let podium = ((r["competitors"] as? [[String: Any]]) ?? [])
                .sorted { ($0["order"] as? Int ?? 99) < ($1["order"] as? Int ?? 99) }.prefix(3)
                .map { lastName((($0["athlete"] as? [String: Any])?["shortName"] as? String) ?? (($0["athlete"] as? [String: Any])?["displayName"] as? String) ?? "?") }
            out.append(SportsEvent(comp: comp, kind: .race(title: title(last), podium: podium), state: .post,
                                   date: date(r["date"] as? String ?? last["date"] as? String), detail: "Result", link: link(last)))
        }
        if let next = events.first(where: { state((($0["status"] as? [String: Any])?["type"] as? [String: Any])?["state"] as? String) != .post }) {
            let r = race(next)
            let st = state((((r?["status"] as? [String: Any])?["type"] as? [String: Any])?["state"] as? String))
            out.append(SportsEvent(comp: comp, kind: .race(title: title(next), podium: []), state: st == .live ? .live : .pre,
                                   date: date(r?["date"] as? String ?? next["date"] as? String), detail: st == .live ? "Live" : "", link: link(next)))
        }
        return out
    }

    /// "L. Norris" → "Norris".
    static func lastName(_ s: String) -> String {
        let parts = s.split(separator: " ")
        return parts.count > 1 && parts[0].hasSuffix(".") ? parts.dropFirst().joined(separator: " ") : s
    }

    /// Drops sponsors from race names: "MSC Cruises São Paulo Grand Prix" → "São Paulo GP".
    static func shortTitle(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "Grand Prix", with: "GP")
        for series in ["NASCAR Cup Series at ", "NASCAR Cup Series - "] where t.hasPrefix(series) { t = String(t.dropFirst(series.count)) }
        for sponsor in ["MSC Cruises ", "Heineken ", "Aramco ", "Pirelli ", "Qatar Airways ", "Lenovo ", "Crypto.com ", "AWS ",
                        "Gulf Air ", "Louis Vuitton ", "Rolex ", "Etihad Airways ", "Singapore Airlines ", "STC ", "Tag Heuer "] {
            t = t.replacingOccurrences(of: sponsor, with: "")
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    static func titleCase(_ s: String) -> String {
        s.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
            .replacingOccurrences(of: "Grand Prix", with: "GP")
    }
}
