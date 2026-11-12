import AppKit
import ServiceManagement

/// Settings: country (which sets the stocks and news sources), stocks, news sources, weather, login.
final class SettingsWindow: NSWindowController, NSTextFieldDelegate {
    let store: Store
    private let country = NSPopUpButton()
    private let stocks = NSTextField()
    private let newsStack = NSStackView()
    private var sportBoxes: [NSButton] = []
    private let city = NSTextField()
    private let cityStatus = NSTextField(labelWithString: "")
    private let useLocation = NSButton(checkboxWithTitle: "Use my current location", target: nil, action: nil)
    private let fahrenheit = NSButton(checkboxWithTitle: "Show °F (Fahrenheit)", target: nil, action: nil)
    private let login = NSButton(checkboxWithTitle: "Open TouchBarDash at login", target: nil, action: nil)

    static let fullNames = [
        "cnbcid": "CNBC Indonesia", "npr": "NPR", "nyt": "The New York Times", "cnbc": "CNBC", "bbc": "BBC News",
        "guardian": "The Guardian", "nhk": "NHK (Japanese)", "japantimes": "The Japan Times", "cna": "CNA",
        "straitstimes": "The Straits Times", "fmt": "Free Malaysia Today", "abc": "ABC News",
        "smh": "The Sydney Morning Herald", "toi": "The Times of India", "hindu": "The Hindu", "lemonde": "Le Monde",
        "france24": "France 24", "yonhap": "Yonhap", "koreaherald": "The Korea Herald", "cbc": "CBC News",
        "globalnews": "Global News", "malaymail": "Malay Mail",
        "taipeitimes": "Taipei Times", "ltn": "Liberty Times (Chinese)",
    ]

    init(store: Store) {
        self.store = store
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "TouchBarDash Settings"
        w.isReleasedWhenClosed = false
        super.init(window: w)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        load()
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible == false { window?.center() }
        window?.makeKeyAndOrderFront(nil)
    }

    private func hint(_ s: String) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: s)
        l.font = .systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor
        l.preferredMaxLayoutWidth = 520
        return l
    }

    private func build() {
        for c in Country.all { country.addItem(withTitle: "\(c.flag)  \(c.name)") }
        country.target = self
        country.action = #selector(countryChanged)

        stocks.placeholderString = "e.g. ^JKSE, BBCA.JK, AAPL, BTC-USD"
        stocks.delegate = self
        stocks.widthAnchor.constraint(equalToConstant: 400).isActive = true
        let reset = NSButton(title: "Reset to Country Defaults", target: self, action: #selector(resetStocks))
        reset.controlSize = .small
        reset.font = .systemFont(ofSize: 11)
        let stocksBox = NSStackView(views: [stocks,
            hint("Yahoo Finance symbols, separated by commas. Press Return to save."), reset])
        stocksBox.orientation = .vertical
        stocksBox.alignment = .leading
        stocksBox.spacing = 4

        newsStack.orientation = .vertical
        newsStack.alignment = .leading
        newsStack.spacing = 4

        city.placeholderString = "City name"
        city.delegate = self
        city.widthAnchor.constraint(equalToConstant: 220).isActive = true
        cityStatus.font = .systemFont(ofSize: 11)
        cityStatus.textColor = .secondaryLabelColor
        let cityRow = NSStackView(views: [city, cityStatus])
        for b in [useLocation, fahrenheit, login] { b.target = self; b.action = #selector(toggled(_:)) }
        let weatherBox = NSStackView(views: [cityRow, useLocation, fahrenheit])
        weatherBox.orientation = .vertical
        weatherBox.alignment = .leading
        weatherBox.spacing = 6

        func label(_ s: String) -> NSTextField {
            let l = NSTextField(labelWithString: s)
            l.font = .systemFont(ofSize: 13, weight: .semibold)
            return l
        }
        let countryBox = NSStackView(views: [country, hint("Picking a country switches the stocks and news to that country.")])
        countryBox.orientation = .vertical
        countryBox.alignment = .leading
        countryBox.spacing = 4
        let grid = NSGridView(views: [
            [label("Country"), countryBox],
            [label("Stocks"), stocksBox],
            [label("News"), newsStack],
            [label("Sports"), sportsGrid()],
            [label("Weather"), weatherBox],
            [label("General"), login],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 14
        grid.column(at: 0).xPlacement = .trailing
        for r in 0..<grid.numberOfRows { grid.row(at: r).yPlacement = .top }
        grid.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
        ])
        window?.contentView = content
    }

    private func load() {
        let c = Settings.country
        country.selectItem(at: Country.all.firstIndex { $0.code == c.code } ?? 0)
        stocks.stringValue = Settings.symbols.joined(separator: ", ")
        newsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let on = Set(Settings.newsSourceIDs)
        for src in c.news {
            let b = NSButton(checkboxWithTitle: Self.fullNames[src.id] ?? src.name.capitalized, target: self, action: #selector(newsToggled(_:)))
            b.identifier = NSUserInterfaceItemIdentifier(src.id)
            b.state = on.contains(src.id) ? .on : .off
            newsStack.addArrangedSubview(b)
        }
        let sportsOn = Set(Settings.sportIDs)
        for b in sportBoxes { b.state = sportsOn.contains(b.identifier?.rawValue ?? "") ? .on : .off }
        city.stringValue = store.place.name
        cityStatus.stringValue = ""
        useLocation.state = Settings.useLocation ? .on : .off
        fahrenheit.state = Settings.fahrenheit ? .on : .off
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        // Countries have different numbers of news sources, so fit the window to its content.
        if let w = window, let v = w.contentView {
            v.layoutSubtreeIfNeeded()
            let top = w.frame.maxY
            w.setContentSize(v.fittingSize)
            w.setFrameTopLeftPoint(NSPoint(x: w.frame.minX, y: top))
        }
    }

    @objc private func countryChanged() {
        Settings.country = Country.all[country.indexOfSelectedItem]
        store.symbolsChanged()
        store.newsSourcesChanged()
        load()
    }

    @objc private func resetStocks() {
        UserDefaults.standard.removeObject(forKey: "symbols")
        store.symbolsChanged()
        load()
    }

    /// Every competition as a checkbox, in three columns: Football, US sports, Motorsport.
    private func sportsGrid() -> NSView {
        let groups = ["Football", "US sports", "Motorsport"]
        let columns: [NSView] = groups.map { g in
            let head = NSTextField(labelWithString: g.uppercased())
            head.font = .systemFont(ofSize: 10, weight: .semibold)
            head.textColor = .secondaryLabelColor
            var views: [NSView] = [head]
            for c in Competition.all where c.group == g {
                let b = NSButton(checkboxWithTitle: c.name, target: self, action: #selector(sportToggled(_:)))
                b.identifier = NSUserInterfaceItemIdentifier(c.id)
                sportBoxes.append(b)
                views.append(b)
            }
            let col = NSStackView(views: views)
            col.orientation = .vertical
            col.alignment = .leading
            col.spacing = 3
            return col
        }
        let row = NSStackView(views: columns)
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 22
        let box = NSStackView(views: [row, hint("Scores and fixtures from ESPN; MotoGP from motogp.com. Live games update every minute.")])
        box.orientation = .vertical
        box.alignment = .leading
        box.spacing = 6
        return box
    }

    @objc private func sportToggled(_ sender: NSButton) {
        let on = Set(sportBoxes.filter { $0.state == .on }.compactMap { $0.identifier?.rawValue })
        Settings.sportIDs = Competition.all.map(\.id).filter { on.contains($0) }
        store.sportsChanged()
    }

    @objc private func newsToggled(_ sender: NSButton) {
        Settings.newsSourceIDs = newsStack.arrangedSubviews.compactMap { v in
            guard let b = v as? NSButton, b.state == .on else { return nil }
            return b.identifier?.rawValue
        }
        store.newsSourcesChanged()
    }

    @objc private func toggled(_ sender: NSButton) {
        switch sender {
        case useLocation:
            if sender.state == .on { store.useCurrentLocation(); cityStatus.stringValue = "Finding you…" }
            else { Settings.useLocation = false }
        case fahrenheit:
            Settings.fahrenheit = sender.state == .on
            store.refreshWeather()
        case login:
            do {
                if sender.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSAlert(error: error).runModal()
                load()
            }
        default: break
        }
    }

    func controlTextDidEndEditing(_ note: Notification) {
        guard let field = note.object as? NSTextField else { return }
        if field === stocks {
            var seen = Set<String>()
            let list = stocks.stringValue.split(whereSeparator: { $0 == "," || $0 == " " })
                .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
                .filter { !$0.isEmpty && seen.insert($0).inserted }
            guard list != Settings.symbols else { return }
            Settings.symbols = list
            store.symbolsChanged()
        } else if field === city {
            let name = city.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, name != store.place.name else { return }
            cityStatus.stringValue = "Looking up…"
            store.setCity(name) { [weak self] ok in
                guard let self else { return }
                self.cityStatus.stringValue = ok ? "✓ \(self.store.place.name)" : "Couldn't find “\(name)”"
                self.useLocation.state = Settings.useLocation ? .on : .off
            }
        }
    }
}
