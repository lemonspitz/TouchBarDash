import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = Store()
    lazy var touchBar = TouchBarController(store: store)
    var statusItem: NSStatusItem!
    lazy var settings = SettingsWindow(store: store)

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⛅️"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        store.onChange = { [weak self] in
            guard let self else { return }
            self.touchBar.refresh()
            self.statusItem.button?.title = self.touchBar.shortTitle
        }
        // Opening at login used to be a System Events login item; switch it to the app's own login item once.
        if !UserDefaults.standard.bool(forKey: "loginMigrated") {
            UserDefaults.standard.set(true, forKey: "loginMigrated")
            try? SMAppService.mainApp.register()
        }
        touchBar.installControlStrip()
        store.start()
        touchBar.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.touchBar.present() }

        // Waking from sleep: data is stale and the Control Strip item may need re-adding.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.touchBar.installControlStrip()
            self?.store.refreshAll()
        }
    }

    /// Opening the app again (double-click in Finder, Launchpad, Spotlight) shows Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()
        return false
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        @discardableResult
        func add(_ title: String, _ action: Selector? = nil, on: Bool = false, key: String = "") -> NSMenuItem {
            let i = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
            i.target = self
            i.state = on ? .on : .off
            return i
        }
        func info(_ s: NSAttributedString) {
            let i = NSMenuItem(title: s.string, action: nil, keyEquivalent: "")
            i.attributedTitle = s
            menu.addItem(i)
        }
        let mono = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)

        if let w = store.weather {
            info(NSAttributedString(string: "\(WMO.emoji(w.code, day: w.isDay))  \(store.place.name): \(deg(w.temp)) \(WMO.text(w.code))",
                                    attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]))
            info(NSAttributedString(string: "     Feels \(deg(w.feels)) · H \(deg(w.hi)) L \(deg(w.lo)) · 💧\(Int(w.humidity))% · 💨\(Int(w.wind.rounded())) \(Settings.fahrenheit ? "mph" : "km/h")",
                                    attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor]))
        } else {
            info(NSAttributedString(string: "Loading weather…"))
        }
        menu.addItem(.separator())
        for sym in Settings.symbols {
            let s = NSMutableAttributedString(string: displayName(sym, quote: store.quotes[sym]).padding(toLength: 11, withPad: " ", startingAt: 0),
                                              attributes: [.font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .semibold)])
            if let q = store.quotes[sym] {
                s.append(NSAttributedString(string: formatPrice(q.price) + "  ", attributes: [.font: mono]))
                s.append(NSAttributedString(string: formatPercent(q.percent), attributes: [.font: mono, .foregroundColor: q.up ? NSColor.systemGreen : NSColor.systemRed]))
            } else {
                s.append(NSAttributedString(string: "…", attributes: [.font: mono]))
            }
            let i = add(sym, #selector(openQuote(_:)))
            i.attributedTitle = s
            i.representedObject = sym
        }
        if !store.news.isEmpty {
            menu.addItem(.separator())
            let sub = NSMenu()
            for n in store.news.prefix(30) {
                let age = News.age(n.date)
                let i = sub.addItem(withTitle: "", action: #selector(openNews(_:)), keyEquivalent: "")
                i.target = self
                i.representedObject = n.link
                let t = NSMutableAttributedString(string: n.source.name + (age.isEmpty ? "" : " · \(age)") + "   ",
                    attributes: [.font: NSFont.systemFont(ofSize: 10.5, weight: .bold), .foregroundColor: n.source.nsColor])
                t.append(NSAttributedString(string: n.title.count > 90 ? String(n.title.prefix(88)) + "…" : n.title,
                                            attributes: [.font: NSFont.menuFont(ofSize: 13)]))
                i.attributedTitle = t
            }
            let news = NSMenuItem(title: "📰  News — \(Settings.country.flag) \(Settings.newsSources.map { $0.name.capitalized }.joined(separator: " & "))", action: nil, keyEquivalent: "")
            news.submenu = sub
            menu.addItem(news)
        }
        menu.addItem(.separator())
        add("Show on Touch Bar", #selector(showBar))
        add("Settings…", #selector(openSettings), key: ",")
        add("Refresh Now", #selector(refresh), key: "r")
        menu.addItem(.separator())
        add("Quit TouchBarDash", #selector(quit), key: "q")
    }

    @objc func openQuote(_ sender: NSMenuItem) {
        guard let sym = sender.representedObject as? String,
              let enc = sym.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-."))),
              let url = URL(string: "https://finance.yahoo.com/quote/\(enc)") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func openNews(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { NSWorkspace.shared.open(url) }
    }

    @objc func showBar() { touchBar.present() }
    @objc func refresh() { store.refreshAll() }
    @objc func quit() { NSApp.terminate(nil) }

    @objc func openSettings() { settings.show() }
}

// MARK: Icon rendering (used by build.sh)

func renderIcons(to dir: String) {
    for size in [16, 32, 64, 128, 256, 512, 1024] {
        let s = CGFloat(size)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        do {
            let rect = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
            let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.18, yRadius: s * 0.18)
            NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.52, blue: 0.92, alpha: 1),
                       ending: NSColor(calibratedRed: 0.06, green: 0.13, blue: 0.30, alpha: 1))!.draw(in: path, angle: -90)
            NSGraphicsContext.current?.saveGraphicsState()
            path.addClip()
            // Rising chart line along the bottom.
            let chart = NSBezierPath()
            let ys: [CGFloat] = [0.30, 0.36, 0.33, 0.42, 0.40, 0.50, 0.47, 0.58]
            for (i, y) in ys.enumerated() {
                let p = NSPoint(x: s * (0.1 + 0.8 * CGFloat(i) / CGFloat(ys.count - 1)), y: s * y)
                i == 0 ? chart.move(to: p) : chart.line(to: p)
            }
            chart.lineWidth = s * 0.045
            chart.lineJoinStyle = .round
            chart.lineCapStyle = .round
            green.setStroke()
            chart.stroke()
            NSGraphicsContext.current?.restoreGraphicsState()
            let sun = NSAttributedString(string: "⛅️", attributes: [.font: NSFont.systemFont(ofSize: s * 0.36)])
            sun.draw(at: NSPoint(x: s * 0.5 - sun.size().width / 2, y: s * 0.48))
        }
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/icon_\(size).png"))
    }
}

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--icon"), i + 1 < args.count {
    renderIcons(to: args[i + 1])
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
