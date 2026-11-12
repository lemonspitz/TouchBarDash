import Foundation
import CoreLocation

// MARK: Models

struct Quote {
    let symbol: String
    var price: Double
    var prevClose: Double
    var points: [Double]
    var currency: String
    var name: String = ""
    var change: Double { price - prevClose }
    var percent: Double { prevClose == 0 ? 0 : change / prevClose * 100 }
    var up: Bool { change >= 0 }
}

struct HourForecast { let date: Date; let temp: Double; let code: Int; let isDay: Bool }

struct Weather {
    var temp: Double, feels: Double, code: Int, isDay: Bool
    var humidity: Double, wind: Double
    var hi: Double, lo: Double
    var hours: [HourForecast]
    var timeZone: TimeZone
}

enum WMO {
    static func emoji(_ code: Int, day: Bool = true) -> String {
        switch code {
        case 0: return day ? "☀️" : "🌙"
        case 1: return day ? "🌤️" : "🌙"
        case 2: return day ? "⛅️" : "☁️"
        case 3: return "☁️"
        case 45, 48: return "🌫️"
        case 51...57: return "🌦️"
        case 61...67: return "🌧️"
        case 71...77, 85, 86: return "🌨️"
        case 80...82: return "🌦️"
        case 95...99: return "⛈️"
        default: return "🌡️"
        }
    }
    static func text(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly clear"
        case 2: return "Partly cloudy"
        case 3: return "Cloudy"
        case 45, 48: return "Fog"
        case 51...57: return "Drizzle"
        case 61...65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71...77: return "Snow"
        case 80...82: return "Showers"
        case 85, 86: return "Snow showers"
        case 95...99: return "Thunderstorm"
        default: return "—"
        }
    }
}

// MARK: Settings

enum Settings {
    static let d = UserDefaults.standard
    /// Chosen country; defaults to the Mac's region if it's one we have presets for, else Indonesia.
    static var country: Country {
        get { Country.find(d.string(forKey: "country")) ?? Country.find(Locale.current.region?.identifier) ?? Country.all[0] }
        set {
            d.set(newValue.code, forKey: "country")
            d.removeObject(forKey: "symbols")
            d.removeObject(forKey: "newsSources")
        }
    }
    static var symbols: [String] {
        get { d.stringArray(forKey: "symbols") ?? country.stocks }
        set { d.set(newValue, forKey: "symbols") }
    }
    static var newsSourceIDs: [String] {
        get { d.stringArray(forKey: "newsSources") ?? country.defaultNewsIDs }
        set { d.set(newValue, forKey: "newsSources") }
    }
    /// Competitions shown in the 🏆 strip, in the order they appear in Competition.all.
    static var sportIDs: [String] {
        get { d.stringArray(forKey: "sports") ?? Competition.defaultIDs }
        set { d.set(newValue, forKey: "sports") }
    }
    static var newsSources: [NewsSource] {
        let on = Set(newsSourceIDs)
        return country.news.filter { on.contains($0.id) }
    }
    static var fahrenheit: Bool {
        get { d.bool(forKey: "fahrenheit") }
        set { d.set(newValue, forKey: "fahrenheit") }
    }
    static var useLocation: Bool {
        get { d.object(forKey: "useLocation") as? Bool ?? true }
        set { d.set(newValue, forKey: "useLocation") }
    }
    static var place: Place {
        get {
            guard let name = d.string(forKey: "placeName") else { return .fallback }
            return Place(name: name, lat: d.double(forKey: "placeLat"), lon: d.double(forKey: "placeLon"))
        }
        set {
            d.set(newValue.name, forKey: "placeName")
            d.set(newValue.lat, forKey: "placeLat")
            d.set(newValue.lon, forKey: "placeLon")
        }
    }
}

struct Place {
    var name: String, lat: Double, lon: Double
    static let fallback = Place(name: "Jakarta", lat: -6.2088, lon: 106.8456)
}

/// Friendly short names for indices, numeric Asian tickers, currencies and crypto.
func displayName(_ symbol: String, quote: Quote? = nil) -> String {
    let names = ["^GSPC": "S&P 500", "^IXIC": "NASDAQ", "^DJI": "DOW", "^JKSE": "IHSG", "^N225": "NIKKEI",
                 "^HSI": "HANG SENG", "^FTSE": "FTSE 100", "^RUT": "RUSSELL", "^VIX": "VIX", "^STI": "STI",
                 "^KLSE": "KLCI", "^AXJO": "ASX 200", "^NSEI": "NIFTY 50", "^BSESN": "SENSEX", "^GDAXI": "DAX",
                 "^KS11": "KOSPI", "^GSPTSE": "TSX", "^FCHI": "CAC 40",
                 "7203.T": "TOYOTA", "6758.T": "SONY", "9984.T": "SOFTBANK", "8306.T": "MUFG",
                 "D05.SI": "DBS", "O39.SI": "OCBC", "U11.SI": "UOB", "Z74.SI": "SINGTEL",
                 "1155.KL": "MAYBANK", "1295.KL": "PUBLIC BANK", "5347.KL": "TENAGA",
                 "^TWII": "TAIEX", "2330.TW": "TSMC", "2317.TW": "FOXCONN", "2454.TW": "MEDIATEK", "2308.TW": "DELTA",
                 "005930.KS": "SAMSUNG", "000660.KS": "SK HYNIX", "035420.KS": "NAVER",
                 "BTC-USD": "BTC", "ETH-USD": "ETH", "SOL-USD": "SOL", "GC=F": "GOLD", "CL=F": "OIL"]
    if let n = names[symbol] { return n }
    if symbol.hasSuffix("=X") {
        let c = symbol.dropLast(2)
        if c.count == 3 { return "USD/\(c)" }
        if c.count == 6 { return "\(c.prefix(3))/\(c.suffix(3))" }
    }
    let root = symbol.split(separator: ".").first.map(String.init) ?? symbol
    // Numeric tickers (Tokyo, Seoul, Bursa…) read better as the company's name.
    if root.allSatisfy(\.isNumber), let n = quote?.name, !n.isEmpty {
        return String(n.uppercased().split(separator: " ").prefix(2).joined(separator: " ").prefix(12))
    }
    return root
}

func formatPrice(_ p: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = p >= 10_000 ? 0 : (p < 1 ? 4 : 2)
    f.minimumFractionDigits = f.maximumFractionDigits
    return f.string(from: NSNumber(value: p)) ?? String(p)
}

func formatPercent(_ p: Double) -> String { String(format: "%@%.2f%%", p >= 0 ? "+" : "−", abs(p)) }

func deg(_ t: Double) -> String { "\(Int(t.rounded()))°" }

// MARK: Store

final class Store: NSObject, CLLocationManagerDelegate {
    private(set) var weather: Weather?
    private(set) var quotes: [String: Quote] = [:]
    private(set) var place = Settings.place
    private(set) var lastStocks: Date?
    private(set) var news: [NewsItem] = []
    private var newsBySource: [String: [NewsItem]] = [:]
    var onChange: (() -> Void)?

    private let location = CLLocationManager()
    private var timers: [Timer] = []
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"]
        c.timeoutIntervalForRequest = 15
        return URLSession(configuration: c)
    }()

    func start() {
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyKilometer
        refreshWeather()
        refreshStocks()
        refreshNews()
        refreshSports()
        if Settings.useLocation { requestLocation() }
        timers = [
            Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
                guard let self else { return }
                if Settings.useLocation { self.requestLocation() } else { self.refreshWeather() }
            },
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refreshStocks() },
            Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in self?.refreshNews() },
            // Scores: every minute while a game or race is live, otherwise every 10 minutes.
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                guard let self else { return }
                if self.sports.contains(where: { $0.state == .live }) || Date().timeIntervalSince(self.lastSports) > 590 { self.refreshSports() }
            },
        ]
    }

    func refreshAll() {
        if Settings.useLocation { requestLocation() } else { refreshWeather() }
        refreshStocks()
        refreshNews()
        refreshSports()
    }

    private func changed() { DispatchQueue.main.async { self.onChange?() } }

    /// Like getJSON, for endpoints that answer with an array.
    private func getAny(_ url: URL, _ done: @escaping (Any?) -> Void) {
        session.dataTask(with: url) { data, _, _ in
            let obj = data.flatMap { try? JSONSerialization.jsonObject(with: $0) }
            DispatchQueue.main.async { done(obj) }
        }.resume()
    }

    private func getJSON(_ url: URL, _ done: @escaping ([String: Any]?) -> Void) {
        session.dataTask(with: url) { data, _, _ in
            let obj = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            DispatchQueue.main.async { done(obj) }
        }.resume()
    }

    // MARK: Weather

    func refreshWeather() {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            .init(name: "latitude", value: String(place.lat)),
            .init(name: "longitude", value: String(place.lon)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,wind_speed_10m"),
            .init(name: "hourly", value: "temperature_2m,weather_code,is_day"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "2"),
            .init(name: "temperature_unit", value: Settings.fahrenheit ? "fahrenheit" : "celsius"),
            .init(name: "wind_speed_unit", value: Settings.fahrenheit ? "mph" : "kmh"),
        ]
        getJSON(c.url!) { [weak self] j in
            guard let self, let j, let cur = j["current"] as? [String: Any] else { return }
            let tz = TimeZone(secondsFromGMT: j["utc_offset_seconds"] as? Int ?? 0) ?? .current
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm"
            df.timeZone = tz
            var hours: [HourForecast] = []
            if let h = j["hourly"] as? [String: Any],
               let times = h["time"] as? [String], let temps = h["temperature_2m"] as? [Double],
               let codes = h["weather_code"] as? [Int], let days = h["is_day"] as? [Int] {
                let now = Date()
                for i in times.indices where i < temps.count && i < codes.count && i < days.count {
                    guard let d = df.date(from: times[i]), d.addingTimeInterval(3600) > now else { continue }
                    hours.append(HourForecast(date: d, temp: temps[i], code: codes[i], isDay: days[i] == 1))
                    if hours.count == 24 { break }
                }
            }
            let daily = j["daily"] as? [String: Any]
            func num(_ any: Any?) -> Double { (any as? Double) ?? Double(any as? Int ?? 0) }
            self.weather = Weather(
                temp: num(cur["temperature_2m"]), feels: num(cur["apparent_temperature"]),
                code: cur["weather_code"] as? Int ?? 0, isDay: (cur["is_day"] as? Int ?? 1) == 1,
                humidity: num(cur["relative_humidity_2m"]), wind: num(cur["wind_speed_10m"]),
                hi: num((daily?["temperature_2m_max"] as? [Any])?.first),
                lo: num((daily?["temperature_2m_min"] as? [Any])?.first),
                hours: hours, timeZone: tz)
            self.changed()
        }
    }

    /// Looks a city up by name with Open-Meteo's geocoder.
    func setCity(_ name: String, done: @escaping (Bool) -> Void) {
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        c.queryItems = [.init(name: "name", value: name), .init(name: "count", value: "1")]
        getJSON(c.url!) { [weak self] j in
            guard let self, let r = (j?["results"] as? [[String: Any]])?.first,
                  let lat = r["latitude"] as? Double, let lon = r["longitude"] as? Double else { return done(false) }
            Settings.useLocation = false
            self.setPlace(Place(name: r["name"] as? String ?? name, lat: lat, lon: lon))
            done(true)
        }
    }

    private func setPlace(_ p: Place) {
        place = p
        Settings.place = p
        refreshWeather()
        changed()
    }

    // MARK: Location

    func useCurrentLocation() {
        Settings.useLocation = true
        requestLocation()
    }

    private func requestLocation() {
        switch location.authorizationStatus {
        case .notDetermined: location.requestWhenInUseAuthorization()
        case .denied, .restricted: refreshWeather()
        default: location.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard Settings.useLocation else { return }
        switch manager.authorizationStatus {
        case .notDetermined: break
        case .denied, .restricted: refreshWeather()
        default: manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard Settings.useLocation, let loc = locations.last else { return }
        let lat = loc.coordinate.latitude, lon = loc.coordinate.longitude
        CLGeocoder().reverseGeocodeLocation(loc) { [weak self] marks, _ in
            DispatchQueue.main.async {
                let name = marks?.first.flatMap { $0.locality ?? $0.subAdministrativeArea ?? $0.administrativeArea } ?? "Here"
                self?.setPlace(Place(name: name, lat: lat, lon: lon))
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        refreshWeather()
    }

    // MARK: News

    func refreshNews() {
        for src in Settings.newsSources {
            guard let url = URL(string: src.url) else { continue }
            getData(url) { [weak self] d in
                guard let d else { return }
                switch src.kind {
                case .kompasIndex: self?.setNews(News.parseKompas(String(decoding: d, as: UTF8.self), source: src), src)
                case .rss: self?.setNews(News.parseRSS(d, source: src), src)
                }
            }
        }
    }

    /// Call after the country or the chosen sources change.
    func newsSourcesChanged() {
        rebuildNews()
        refreshNews()
    }

    private func setNews(_ items: [NewsItem], _ source: NewsSource) {
        guard !items.isEmpty else { return }
        newsBySource[source.id] = Array(items.prefix(20))
        rebuildNews()
    }

    private func rebuildNews() {
        let on = Set(Settings.newsSources.map(\.id))
        newsBySource = newsBySource.filter { on.contains($0.key) }
        news = newsBySource.values.flatMap { $0 }.sorted { $0.date > $1.date }
        changed()
    }

    private func getData(_ url: URL, _ done: @escaping (Data?) -> Void) {
        session.dataTask(with: url) { data, resp, _ in
            let ok = (resp as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async { done(ok ? data : nil) }
        }.resume()
    }

    // MARK: Sports

    private(set) var sports: [SportsEvent] = []
    private var sportsByComp: [String: [SportsEvent]] = [:]
    private var lastSports = Date.distantPast

    func refreshSports() {
        lastSports = Date()
        let espn = "https://site.api.espn.com/apis/site/v2/sports/"
        for comp in Settings.sportIDs.compactMap(Competition.find) {
            switch comp.source {
            case .espn(let path):
                getJSON(URL(string: espn + path + "/scoreboard")!) { [weak self] j in
                    guard let j else { return }
                    self?.setSports(SportsFetch.parseTeams(j, comp), comp)
                }
            case .espnRacing(let path):
                // Two months either side: the last race's result and the next race.
                let f = DateFormatter()
                f.dateFormat = "yyyyMMdd"
                f.locale = Locale(identifier: "en_US_POSIX")
                let range = f.string(from: Date().addingTimeInterval(-60 * 86400)) + "-" + f.string(from: Date().addingTimeInterval(75 * 86400))
                getJSON(URL(string: espn + path + "/scoreboard?dates=" + range)!) { [weak self] j in
                    guard let j else { return }
                    self?.setSports(SportsFetch.parseRacing(j, comp), comp)
                }
            case .motoGP:
                fetchMotoGP(comp)
            }
        }
    }

    func sportsChanged() {
        let on = Set(Settings.sportIDs)
        sportsByComp = sportsByComp.filter { on.contains($0.key) }
        rebuildSports()
        refreshSports()
    }

    private func setSports(_ events: [SportsEvent], _ comp: Competition) {
        guard Settings.sportIDs.contains(comp.id) else { return }
        sportsByComp[comp.id] = events
        rebuildSports()
    }

    /// Competitions in list order; within each, live games, then results (newest first), then upcoming (soonest first).
    private func rebuildSports() {
        let rank: (SportsEvent.State) -> Int = { $0 == .live ? 0 : $0 == .post ? 1 : 2 }
        sports = Competition.all.flatMap { comp in
            (sportsByComp[comp.id] ?? []).sorted { a, b in
                if rank(a.state) != rank(b.state) { return rank(a.state) < rank(b.state) }
                return a.state == .post ? a.date > b.date : a.date < b.date
            }
        }
        changed()
    }

    /// MotoGP's own results service: the last Grand Prix podium and the next Grand Prix.
    private func fetchMotoGP(_ comp: Competition) {
        let base = "https://api.motogp.pulselive.com/motogp/v1/results"
        let link = URL(string: "https://www.motogp.com/en/gp-results")
        func url(_ p: String) -> URL { URL(string: base + p)! }
        func title(_ e: [String: Any]) -> String {
            let n = (e["name"] as? String ?? "MotoGP").uppercased()
            if n.hasPrefix("GRAND PRIX OF ") { return SportsFetch.titleCase(String(n.dropFirst(14))) + " GP" }
            return SportsFetch.titleCase(n)
        }
        func day(_ s: String?) -> Date {
            guard let s else { return .distantPast }
            let iso = ISO8601DateFormatter()
            if let d = iso.date(from: s) { return d }
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"
            return f.date(from: String(s.prefix(10))) ?? .distantPast
        }
        getAny(url("/seasons")) { [weak self] seasons in
            guard let self, let season = (seasons as? [[String: Any]])?.first(where: { $0["current"] as? Bool == true }),
                  let sid = season["id"] as? String else { return }
            var result: SportsEvent?, next: SportsEvent?
            let group = DispatchGroup()
            group.enter()
            self.getAny(url("/events?seasonUuid=\(sid)&isFinished=false")) { list in
                defer { group.leave() }
                let upcoming = ((list as? [[String: Any]]) ?? []).filter { $0["test"] as? Bool != true }
                    .sorted { day($0["date_start"] as? String) < day($1["date_start"] as? String) }
                if let e = upcoming.first {
                    next = SportsEvent(comp: comp, kind: .race(title: title(e), podium: []), state: .pre,
                                       date: day(e["date_end"] as? String), detail: "", link: link)
                }
            }
            group.enter()
            self.getAny(url("/events?seasonUuid=\(sid)&isFinished=true")) { list in
                let done = ((list as? [[String: Any]]) ?? []).filter { $0["test"] as? Bool != true }
                    .sorted { day($0["date_end"] as? String) < day($1["date_end"] as? String) }
                guard let e = done.last, let eid = e["id"] as? String else { group.leave(); return }
                self.getAny(url("/categories?eventUuid=\(eid)")) { cats in
                    guard let cat = (cats as? [[String: Any]])?.first(where: { ($0["name"] as? String ?? "").hasPrefix("MotoGP") }),
                          let cid = cat["id"] as? String else { group.leave(); return }
                    self.getAny(url("/sessions?eventUuid=\(eid)&categoryUuid=\(cid)")) { sessions in
                        guard let race = (sessions as? [[String: Any]])?.last(where: { $0["type"] as? String == "RAC" }),
                              let rid = race["id"] as? String else { group.leave(); return }
                        self.getAny(url("/session/\(rid)/classification?test=false")) { cl in
                            let rows = ((cl as? [String: Any])?["classification"] as? [[String: Any]]) ?? []
                            let podium = rows.prefix(3).map { r -> String in
                                let full = (r["rider"] as? [String: Any])?["full_name"] as? String ?? "?"
                                return full.split(separator: " ").last.map(String.init) ?? full
                            }
                            result = SportsEvent(comp: comp, kind: .race(title: title(e), podium: podium), state: .post,
                                                 date: day(e["date_end"] as? String), detail: "Result", link: link)
                            group.leave()
                        }
                    }
                }
            }
            group.notify(queue: .main) { self.setSports([result, next].compactMap { $0 }, comp) }
        }
    }

    // MARK: Stocks

    func refreshStocks() {
        for sym in Settings.symbols { fetchQuote(sym) }
    }

    func symbolsChanged() {
        let keep = Set(Settings.symbols)
        quotes = quotes.filter { keep.contains($0.key) }
        changed()
        refreshStocks()
    }

    private func fetchQuote(_ sym: String) {
        let enc = sym.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-."))) ?? sym
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(enc)?range=1d&interval=5m") else { return }
        getJSON(url) { [weak self] j in
            guard let self, Settings.symbols.contains(sym),
                  let r = ((j?["chart"] as? [String: Any])?["result"] as? [[String: Any]])?.first,
                  let meta = r["meta"] as? [String: Any],
                  let price = meta["regularMarketPrice"] as? Double else { return }
            let prev = meta["chartPreviousClose"] as? Double ?? meta["previousClose"] as? Double ?? price
            let closes = (((r["indicators"] as? [String: Any])?["quote"] as? [[String: Any]])?.first?["close"] as? [Any]) ?? []
            let pts = closes.compactMap { $0 as? Double }
            self.quotes[sym] = Quote(symbol: sym, price: price, prevClose: prev, points: pts, currency: meta["currency"] as? String ?? "",
                                      name: meta["shortName"] as? String ?? "")
            self.lastStocks = Date()
            self.changed()
        }
    }
}

// MARK: News (Kompas + Tempo)

struct NewsItem {
    let source: NewsSource, title: String, link: URL, date: Date
}

enum News {
    static let wib = TimeZone(identifier: "Asia/Jakarta")!

    /// Kompas has no public RSS feed, so headlines come from its latest-news index page.
    static func parseKompas(_ html: String, source: NewsSource) -> [NewsItem] {
        let re = try! NSRegularExpression(
            pattern: #"<a class="article-link" href="([^"]+)">.*?<h2 class="articleTitle">\s*(.*?)\s*</h2>"#,
            options: [.dotMatchesLineSeparators])
        let dateRe = try! NSRegularExpression(pattern: #"/read/(\d{4})/(\d{2})/(\d{2})/(\d{2})(\d{2})"#)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = wib
        let ns = html as NSString
        return re.matches(in: html, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let href = ns.substring(with: m.range(at: 1))
            guard let url = URL(string: href) else { return nil }
            var date = Date.distantPast
            if let d = dateRe.firstMatch(in: href, range: NSRange(location: 0, length: (href as NSString).length)) {
                let n = (1...5).map { Int((href as NSString).substring(with: d.range(at: $0))) ?? 0 }
                date = cal.date(from: DateComponents(year: n[0], month: n[1], day: n[2], hour: n[3], minute: n[4])) ?? date
            }
            return NewsItem(source: source, title: unescape(ns.substring(with: m.range(at: 2))), link: url, date: date)
        }
    }

    static func parseRSS(_ data: Data, source: NewsSource) -> [NewsItem] {
        let p = RSSParser()
        let x = XMLParser(data: data)
        x.delegate = p
        x.parse()
        return p.items.compactMap { i in
            guard let url = URL(string: i["link", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)),
                  url.host.map({ h in source.hostSuffix.map { h.hasSuffix($0) } ?? true }) ?? false else { return nil }
            let title = unescape(i["title", default: ""].trimmingCharacters(in: .whitespacesAndNewlines))
            guard !title.isEmpty else { return nil }
            return NewsItem(source: source, title: title, link: url, date: parseDate(i["pubDate"] ?? i["date"] ?? ""))
        }
    }

    private static let rfcFormatters: [DateFormatter] = [
        "EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, dd MMM yyyy HH:mm:ss xxx",
        "EEE, dd MMM yyyy HH:mm Z", "EEE, dd MMM yyyy HH:mm zzz", "dd MMM yyyy HH:mm:ss Z",
    ].map { f in
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = f
        return df
    }

    static func parseDate(_ raw: String) -> Date {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return .distantPast }
        for f in rfcFormatters { if let d = f.date(from: s) { return d } }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: s) ?? .distantPast
    }

    static func unescape(_ s: String) -> String {
        var s = s
        for (k, v) in ["&amp;": "&", "&quot;": "\"", "&#039;": "'", "&#39;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "] {
            s = s.replacingOccurrences(of: k, with: v)
        }
        return s
    }

    static func age(_ d: Date) -> String {
        let m = Int(Date().timeIntervalSince(d) / 60)
        if d == .distantPast { return "" }
        if m < 1 { return "now" }
        if m < 60 { return "\(m)m" }
        if m < 60 * 24 { return "\(m / 60)h" }
        return "\(m / 1440)d"
    }
}

final class RSSParser: NSObject, XMLParserDelegate {
    var items: [[String: String]] = []
    private var current: [String: String]?
    private var key: String?

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        if name == "item" { current = [:] }
        else if current != nil, ["title", "link", "pubDate", "dc:date"].contains(name) { key = name == "dc:date" ? "date" : name }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if let key { current?[key, default: ""] += string }
    }
    func parser(_ parser: XMLParser, foundCDATA data: Data) {
        if let key, let s = String(data: data, encoding: .utf8) { current?[key, default: ""] += s }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "item", let c = current { items.append(c); current = nil }
        if name == key || (name == "dc:date" && key == "date") { key = nil }
    }
}
