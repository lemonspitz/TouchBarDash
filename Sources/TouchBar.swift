import AppKit

extension NSTouchBarItem.Identifier {
    static let controlStrip = NSTouchBarItem.Identifier("com.lemonspitz.touchbardash.controlstrip")
    static let weather = NSTouchBarItem.Identifier("com.lemonspitz.touchbardash.weather")
    static let strip = NSTouchBarItem.Identifier("com.lemonspitz.touchbardash.strip")
    static let mode = NSTouchBarItem.Identifier("com.lemonspitz.touchbardash.mode")
}

/// Private DFRFoundation / NSTouchBar entry points for a Control Strip button and a system-wide bar.
enum SystemTouchBar {
    private static let dfr = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW)

    static func setControlStripPresence(_ id: NSTouchBarItem.Identifier, _ present: Bool) {
        typealias Fn = @convention(c) (CFString, Bool) -> Void
        guard let sym = dlsym(dfr, "DFRElementSetControlStripPresenceForIdentifier") else { return }
        unsafeBitCast(sym, to: Fn.self)(id.rawValue as CFString, present)
    }

    static func showCloseBox(_ show: Bool) {
        typealias Fn = @convention(c) (Bool) -> Void
        guard let sym = dlsym(dfr, "DFRSystemModalShowsCloseBoxWhenFrontMost") else { return }
        unsafeBitCast(sym, to: Fn.self)(show)
    }

    static func addSystemTrayItem(_ item: NSTouchBarItem) {
        let sel = NSSelectorFromString("addSystemTrayItem:")
        let cls: AnyObject = NSTouchBarItem.self
        if cls.responds(to: sel) { _ = cls.perform(sel, with: item) }
    }

    static func present(_ bar: NSTouchBar, trayID: NSTouchBarItem.Identifier) {
        let cls: AnyObject = NSTouchBar.self
        let modern = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
        let legacy = NSSelectorFromString("presentSystemModalFunctionBar:systemTrayItemIdentifier:")
        if cls.responds(to: modern) { _ = cls.perform(modern, with: bar, with: trayID.rawValue as NSString) }
        else if cls.responds(to: legacy) { _ = cls.perform(legacy, with: bar, with: trayID.rawValue as NSString) }
    }
}

let green = NSColor(calibratedRed: 0.20, green: 0.84, blue: 0.42, alpha: 1)
let red = NSColor(calibratedRed: 1.00, green: 0.33, blue: 0.33, alpha: 1)

func text(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight = .regular, _ color: NSColor = .white) -> NSAttributedString {
    NSAttributedString(string: s, attributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight), .foregroundColor: color])
}

// MARK: Weather panel (left)

final class WeatherView: NSView {
    var weather: Weather?
    var place = ""
    var showingForecast = false
    var onTap: (() -> Void)?
    static let width: CGFloat = 250

    override init(frame: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: 30))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        heightAnchor.constraint(equalToConstant: 30).isActive = true
        let tap = NSClickGestureRecognizer(target: self, action: #selector(tapped))
        tap.allowedTouchTypes = [.direct]
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var intrinsicContentSize: NSSize { NSSize(width: Self.width, height: 30) }
    @objc private func tapped() { onTap?() }

    override func draw(_ dirtyRect: NSRect) {
        let bg = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        (showingForecast ? NSColor(white: 1, alpha: 0.22) : NSColor(white: 1, alpha: 0.10)).setFill()
        bg.fill()
        guard let w = weather else {
            text("⏳ Loading weather…", 12, .medium, .secondaryLabelColor).draw(at: NSPoint(x: 10, y: 8))
            return
        }
        let icon = NSAttributedString(string: WMO.emoji(w.code, day: w.isDay), attributes: [.font: NSFont.systemFont(ofSize: 19)])
        icon.draw(at: NSPoint(x: 6, y: 3))
        let t = text(deg(w.temp), 18, .semibold)
        t.draw(at: NSPoint(x: 34, y: 4))
        let x = 34 + t.size().width + 8
        text("\(place) · \(WMO.text(w.code))", 10.5, .medium).draw(at: NSPoint(x: x, y: 15))
        text("H \(deg(w.hi))  L \(deg(w.lo))  💧\(Int(w.humidity))%", 10, .regular, NSColor(white: 1, alpha: 0.7))
            .draw(at: NSPoint(x: x, y: 2))
    }
}

// MARK: Scrolling strip (right): stocks or hourly forecast

final class StripView: NSView {
    enum Cell { case stock(String, Quote?), hour(HourForecast, TimeZone, first: Bool), news(NewsItem), message(String) }
    var cells: [Cell] = [] { didSet { relayout() } }
    var onTapStock: ((String) -> Void)?
    var onTapNews: ((NewsItem) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        let tap = NSClickGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.allowedTouchTypes = [.direct]
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func width(_ c: Cell) -> CGFloat {
        switch c {
        case .stock: return 176
        case .hour: return 58
        case .news(let n): return min(max(text(n.title, 11, .medium).size().width + 18, 190), 440)
        case .message: return 400
        }
    }

    private var frames: [NSRect] {
        var x: CGFloat = 0
        return cells.map { c in
            let r = NSRect(x: x, y: 0, width: width(c), height: 30)
            x += r.width + 4
            return r
        }
    }

    private func relayout() {
        let w = (frames.last?.maxX ?? 0)
        setFrameSize(NSSize(width: max(w, superview?.bounds.width ?? 0), height: 30))
        needsDisplay = true
    }

    @objc private func tapped(_ g: NSClickGestureRecognizer) {
        let p = g.location(in: self)
        guard let i = frames.firstIndex(where: { $0.contains(p) }) else { return }
        switch cells[i] {
        case .stock(let sym, _): onTapStock?(sym)
        case .news(let n): onTapNews?(n)
        default: break
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        for (c, r) in zip(cells, frames) where r.intersects(dirtyRect) {
            NSColor(white: 1, alpha: 0.08).setFill()
            NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6).fill()
            switch c {
            case .stock(let sym, let q): drawStock(sym, q, in: r)
            case .hour(let h, let tz, let first): drawHour(h, tz, first, in: r)
            case .news(let n): drawNews(n, in: r)
            case .message(let m): text(m, 12, .medium, .secondaryLabelColor).draw(at: NSPoint(x: r.minX + 10, y: 8))
            }
        }
    }

    private func drawStock(_ sym: String, _ q: Quote?, in r: NSRect) {
        let name = displayName(sym, quote: q)
        guard let q else {
            text(name, 11, .bold).draw(at: NSPoint(x: r.minX + 8, y: 15))
            text("…", 11, .regular, .secondaryLabelColor).draw(at: NSPoint(x: r.minX + 8, y: 2))
            return
        }
        let color = q.up ? green : red
        let price = text(formatPrice(q.price), 11, .medium, NSColor(white: 1, alpha: 0.9))
        price.draw(at: NSPoint(x: r.minX + 8, y: 2))
        let pct = text((q.up ? "▲" : "▼") + formatPercent(q.percent).dropFirst(), 10, .semibold, color)
        pct.draw(at: NSPoint(x: r.maxX - 62 - pct.size().width - 6, y: 15.5))
        // Name gets whatever room the percentage leaves, truncated with "…" if needed.
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        NSAttributedString(string: name, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold), .foregroundColor: NSColor.white, .paragraphStyle: style,
        ]).draw(in: NSRect(x: r.minX + 8, y: 15, width: r.maxX - 62 - pct.size().width - 10 - (r.minX + 8), height: 14))

        // Sparkline of today's prices, with yesterday's close as a dotted baseline.
        let spark = NSRect(x: r.maxX - 62, y: 4, width: 56, height: 22)
        let pts = q.points.isEmpty ? [q.prevClose, q.price] : q.points
        let lo = min(pts.min()!, q.prevClose), hi = max(pts.max()!, q.prevClose)
        let span = max(hi - lo, 1e-9)
        func y(_ v: Double) -> CGFloat { spark.minY + CGFloat((v - lo) / span) * spark.height }
        let base = NSBezierPath()
        base.move(to: NSPoint(x: spark.minX, y: y(q.prevClose)))
        base.line(to: NSPoint(x: spark.maxX, y: y(q.prevClose)))
        base.setLineDash([1.5, 2], count: 2, phase: 0)
        base.lineWidth = 0.75
        NSColor(white: 1, alpha: 0.35).setStroke()
        base.stroke()
        let line = NSBezierPath()
        for (i, v) in pts.enumerated() {
            let x = spark.minX + CGFloat(i) / CGFloat(max(pts.count - 1, 1)) * spark.width
            i == 0 ? line.move(to: NSPoint(x: x, y: y(v))) : line.line(to: NSPoint(x: x, y: y(v)))
        }
        line.lineWidth = 1.3
        line.lineJoinStyle = .round
        color.setStroke()
        line.stroke()
    }

    private func drawNews(_ n: NewsItem, in r: NSRect) {
        let tag = text(n.source.name, 8.5, .heavy, n.source.nsColor)
        tag.draw(at: NSPoint(x: r.minX + 8, y: 17.5))
        let age = News.age(n.date)
        if !age.isEmpty {
            text("· " + age, 8.5, .medium, NSColor(white: 1, alpha: 0.55)).draw(at: NSPoint(x: r.minX + 12 + tag.size().width, y: 17.5))
        }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        NSAttributedString(string: n.title, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white, .paragraphStyle: style,
        ]).draw(in: NSRect(x: r.minX + 8, y: 1, width: r.width - 14, height: 15))
    }

    private func drawHour(_ h: HourForecast, _ tz: TimeZone, _ first: Bool, in r: NSRect) {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        df.timeZone = tz
        let label = text(first ? "Now" : df.string(from: h.date), 9.5, .medium, NSColor(white: 1, alpha: 0.65))
        label.draw(at: NSPoint(x: r.midX - label.size().width / 2, y: 17))
        let v = NSMutableAttributedString(attributedString: NSAttributedString(
            string: WMO.emoji(h.code, day: h.isDay) + " ", attributes: [.font: NSFont.systemFont(ofSize: 11)]))
        v.append(text(deg(h.temp), 11.5, .semibold))
        v.draw(at: NSPoint(x: r.midX - v.size().width / 2, y: 2))
    }
}

// MARK: Controller

final class TouchBarController: NSObject, NSTouchBarDelegate {
    let store: Store
    private var bar: NSTouchBar?
    private let stripButton = NSButton(title: "⛅️", target: nil, action: nil)
    private let weatherView = WeatherView()
    enum Mode: Int { case stocks, news, forecast }
    private var mode = Mode(rawValue: UserDefaults.standard.integer(forKey: "stripMode")) ?? .stocks
    private lazy var lastNonForecast = mode == .forecast ? Mode.stocks : mode
    private lazy var modePicker: NSSegmentedControl = {
        let c = NSSegmentedControl(labels: ["📈", "📰", "🌦️"], trackingMode: .selectOne, target: self, action: #selector(modePicked(_:)))
        c.selectedSegment = mode.rawValue
        for i in 0..<3 { c.setWidth(36, forSegment: i) }
        return c
    }()
    private let strip = StripView(frame: NSRect(x: 0, y: 0, width: 800, height: 30))
    private lazy var scroll: NSScrollView = {
        let s = NSScrollView(frame: NSRect(x: 0, y: 0, width: 800, height: 30))
        s.drawsBackground = false
        s.hasHorizontalScroller = false
        s.hasVerticalScroller = false
        s.horizontalScrollElasticity = .allowed
        s.verticalScrollElasticity = .none
        s.documentView = strip
        s.autoresizingMask = [.width, .height]
        return s
    }()
    private lazy var stripHost: NSView = {
        let v = FillView(frame: NSRect(x: 0, y: 0, width: 800, height: 30))
        v.addSubview(scroll)
        v.onResize = { [weak self] in
            guard let self else { return }
            self.strip.cells = self.strip.cells
            self.scrollToStart()
        }
        return v
    }()

    init(store: Store) {
        self.store = store
        super.init()
        weatherView.onTap = { [weak self] in
            guard let self else { return }
            self.setMode(self.mode == .forecast ? self.lastNonForecast : .forecast)
        }
        strip.onTapNews = { NSWorkspace.shared.open($0.link) }
        strip.onTapStock = { sym in
            let enc = sym.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-."))) ?? sym
            if let url = URL(string: "https://finance.yahoo.com/quote/\(enc)") { NSWorkspace.shared.open(url) }
        }
    }

    func installControlStrip() {
        stripButton.target = self
        stripButton.action = #selector(present)
        let item = NSCustomTouchBarItem(identifier: .controlStrip)
        item.view = stripButton
        SystemTouchBar.addSystemTrayItem(item)
        SystemTouchBar.setControlStripPresence(.controlStrip, true)
    }

    @objc private func modePicked(_ c: NSSegmentedControl) { setMode(Mode(rawValue: c.selectedSegment) ?? .stocks) }

    private func setMode(_ m: Mode) {
        if m != .forecast { lastNonForecast = m }
        mode = m
        UserDefaults.standard.set(m.rawValue, forKey: "stripMode")
        modePicker.selectedSegment = m.rawValue
        weatherView.showingForecast = m == .forecast
        refresh()
        scrollToStart()
    }

    @objc func present() {
        if bar == nil {
            let b = NSTouchBar()
            b.delegate = self
            b.defaultItemIdentifiers = [.mode, .strip]
            bar = b
        }
        refresh()
        SystemTouchBar.showCloseBox(true)
        SystemTouchBar.present(bar!, trayID: .controlStrip)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.scrollToStart() }
    }

    private func scrollToStart() {
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    /// Short summary like "⛅️ 30°" for the Control Strip and the menu bar.
    var shortTitle: String {
        guard let w = store.weather else { return "⛅️" }
        return "\(WMO.emoji(w.code, day: w.isDay)) \(deg(w.temp))"
    }

    func refresh() {
        stripButton.title = shortTitle
        weatherView.weather = store.weather
        weatherView.place = store.place.name
        weatherView.showingForecast = mode == .forecast
        weatherView.needsDisplay = true
        switch mode {
        case .forecast:
            let hours = store.weather?.hours ?? []
            strip.cells = hours.isEmpty ? [.message("No forecast yet")] :
                hours.enumerated().map { .hour($1, store.weather!.timeZone, first: $0 == 0) }
        case .news:
            strip.cells = store.news.isEmpty ? [.message(Settings.newsSources.isEmpty ? "No news sources — pick some in Settings" : "⏳ Loading news…")] : store.news.map { .news($0) }
        case .stocks:
            let syms = Settings.symbols
            strip.cells = syms.isEmpty ? [.message("No stocks — add some from the menu bar ⛅️ menu")] :
                syms.map { .stock($0, store.quotes[$0]) }
        }
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        let item = NSCustomTouchBarItem(identifier: identifier)
        switch identifier {
        case .weather: item.view = weatherView
        case .strip: item.view = stripHost
        case .mode: item.view = modePicker
        default: return nil
        }
        return item
    }
}

/// Stretches to fill the rest of the Touch Bar (a bare NSScrollView has no size of its own there).
final class FillView: NSView {
    var onResize: (() -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 30).isActive = true
        widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        let wide = widthAnchor.constraint(equalToConstant: 2000)
        wide.priority = .defaultLow
        wide.isActive = true
        setContentCompressionResistancePriority(.fittingSizeCompression, for: .horizontal)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var intrinsicContentSize: NSSize { NSSize(width: 300, height: 30) }
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        onResize?()
    }
}
