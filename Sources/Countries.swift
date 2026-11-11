import AppKit

struct NewsSource {
    enum Kind { case rss, kompasIndex }
    let id: String
    let name: String
    let url: String
    var kind = Kind.rss
    /// Keep only links on this domain (some feeds mix in sister sites).
    var hostSuffix: String? = nil
    let color: UInt32

    var nsColor: NSColor {
        NSColor(calibratedRed: CGFloat(color >> 16 & 0xFF) / 255, green: CGFloat(color >> 8 & 0xFF) / 255,
                blue: CGFloat(color & 0xFF) / 255, alpha: 1)
    }
}

struct Country {
    let code: String, flag: String, name: String
    let stocks: [String]
    /// The first two are switched on by default.
    let news: [NewsSource]

    static let all: [Country] = [
        Country(code: "ID", flag: "🇮🇩", name: "Indonesia",
                stocks: ["^JKSE", "BBCA.JK", "BBRI.JK", "BMRI.JK", "TLKM.JK", "ASII.JK", "IDR=X"],
                news: [NewsSource(id: "kompas", name: "KOMPAS", url: "https://indeks.kompas.com/", kind: .kompasIndex, color: 0x409AFF),
                       NewsSource(id: "tempo", name: "TEMPO", url: "https://rss.tempo.co/", hostSuffix: "tempo.co", color: 0xFF5C4D),
                       NewsSource(id: "cnbcid", name: "CNBC ID", url: "https://www.cnbcindonesia.com/news/rss", color: 0x3D8BFF),
                       NewsSource(id: "antara", name: "ANTARA", url: "https://www.antaranews.com/rss/terkini.xml", color: 0x32C27A)]),
        Country(code: "US", flag: "🇺🇸", name: "United States",
                stocks: ["^GSPC", "^IXIC", "^DJI", "AAPL", "NVDA", "MSFT", "TSLA", "BTC-USD"],
                news: [NewsSource(id: "npr", name: "NPR", url: "https://feeds.npr.org/1001/rss.xml", color: 0x5B9BFF),
                       NewsSource(id: "nyt", name: "NYT", url: "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml", color: 0xDDDDDD),
                       NewsSource(id: "cnbc", name: "CNBC", url: "https://www.cnbc.com/id/100003114/device/rss/rss.html", color: 0x4FA3FF)]),
        Country(code: "GB", flag: "🇬🇧", name: "United Kingdom",
                stocks: ["^FTSE", "SHEL.L", "AZN.L", "HSBA.L", "ULVR.L", "GBPUSD=X"],
                news: [NewsSource(id: "bbc", name: "BBC", url: "https://feeds.bbci.co.uk/news/rss.xml", color: 0xFF4D4D),
                       NewsSource(id: "guardian", name: "GUARDIAN", url: "https://www.theguardian.com/uk/rss", color: 0x5AA0FF)]),
        Country(code: "JP", flag: "🇯🇵", name: "Japan",
                stocks: ["^N225", "7203.T", "6758.T", "9984.T", "8306.T", "JPY=X"],
                news: [NewsSource(id: "nhk", name: "NHK", url: "https://www.nhk.or.jp/rss/news/cat0.xml", color: 0xBBBBBB),
                       NewsSource(id: "japantimes", name: "JAPAN TIMES", url: "https://www.japantimes.co.jp/feed/", color: 0xFF5C5C)]),
        Country(code: "SG", flag: "🇸🇬", name: "Singapore",
                stocks: ["^STI", "D05.SI", "O39.SI", "U11.SI", "Z74.SI", "SGD=X"],
                news: [NewsSource(id: "cna", name: "CNA", url: "https://www.channelnewsasia.com/rssfeeds/8395986", color: 0xFF5C5C),
                       NewsSource(id: "straitstimes", name: "STRAITS TIMES", url: "https://www.straitstimes.com/news/singapore/rss.xml", color: 0x5AA0FF)]),
        Country(code: "MY", flag: "🇲🇾", name: "Malaysia",
                stocks: ["^KLSE", "1155.KL", "1295.KL", "5347.KL", "MYR=X"],
                news: [NewsSource(id: "malaymail", name: "MALAY MAIL", url: "https://www.malaymail.com/feed/rss/", color: 0xFF5C5C),
                       NewsSource(id: "fmt", name: "FMT", url: "https://www.freemalaysiatoday.com/feed/", color: 0x5AA0FF)]),
        Country(code: "AU", flag: "🇦🇺", name: "Australia",
                stocks: ["^AXJO", "BHP.AX", "CBA.AX", "CSL.AX", "AUDUSD=X"],
                news: [NewsSource(id: "abc", name: "ABC", url: "https://www.abc.net.au/news/feed/51120/rss.xml", color: 0xDDDDDD),
                       NewsSource(id: "smh", name: "SMH", url: "https://www.smh.com.au/rss/feed.xml", color: 0x5AA0FF)]),
        Country(code: "IN", flag: "🇮🇳", name: "India",
                stocks: ["^NSEI", "^BSESN", "RELIANCE.NS", "TCS.NS", "HDFCBANK.NS", "INR=X"],
                news: [NewsSource(id: "toi", name: "TOI", url: "https://timesofindia.indiatimes.com/rssfeedstopstories.cms", color: 0xFF5C5C),
                       NewsSource(id: "hindu", name: "THE HINDU", url: "https://www.thehindu.com/news/national/feeder/default.rss", color: 0x5AA0FF)]),
        Country(code: "DE", flag: "🇩🇪", name: "Germany",
                stocks: ["^GDAXI", "SAP.DE", "SIE.DE", "ALV.DE", "EURUSD=X"],
                news: [NewsSource(id: "tagesschau", name: "TAGESSCHAU", url: "https://www.tagesschau.de/xml/rss2/", color: 0x5AA0FF),
                       NewsSource(id: "spiegel", name: "SPIEGEL", url: "https://www.spiegel.de/schlagzeilen/index.rss", color: 0xFF7A3D)]),
        Country(code: "FR", flag: "🇫🇷", name: "France",
                stocks: ["^FCHI", "MC.PA", "OR.PA", "TTE.PA", "AIR.PA", "EURUSD=X"],
                news: [NewsSource(id: "lemonde", name: "LE MONDE", url: "https://www.lemonde.fr/rss/une.xml", color: 0xDDDDDD),
                       NewsSource(id: "france24", name: "FRANCE 24", url: "https://www.france24.com/fr/rss", color: 0x5AA0FF)]),
        Country(code: "TW", flag: "🇹🇼", name: "Taiwan",
                stocks: ["^TWII", "2330.TW", "2317.TW", "2454.TW", "2308.TW", "TWD=X", "TWDIDR=X"],
                news: [NewsSource(id: "taipeitimes", name: "TAIPEI TIMES", url: "https://www.taipeitimes.com/xml/index.rss", color: 0x5AA0FF),
                       NewsSource(id: "ltn", name: "LIBERTY TIMES", url: "https://news.ltn.com.tw/rss/all.xml", color: 0x3DC27A)]),
        Country(code: "KR", flag: "🇰🇷", name: "South Korea",
                stocks: ["^KS11", "005930.KS", "000660.KS", "035420.KS", "KRW=X"],
                news: [NewsSource(id: "yonhap", name: "YONHAP", url: "https://en.yna.co.kr/RSS/news.xml", color: 0x5AA0FF),
                       NewsSource(id: "koreaherald", name: "KOREA HERALD", url: "https://www.koreaherald.com/rss/newsAll", color: 0xFF5C5C)]),
        Country(code: "CA", flag: "🇨🇦", name: "Canada",
                stocks: ["^GSPTSE", "RY.TO", "SHOP.TO", "TD.TO", "CAD=X"],
                news: [NewsSource(id: "cbc", name: "CBC", url: "https://www.cbc.ca/webfeed/rss/rss-topstories", color: 0xFF5C5C),
                       NewsSource(id: "globalnews", name: "GLOBAL NEWS", url: "https://globalnews.ca/feed/", color: 0x5AA0FF)]),
    ]

    static func find(_ code: String?) -> Country? { all.first { $0.code == code } }

    var defaultNewsIDs: [String] { news.prefix(2).map(\.id) }
}
