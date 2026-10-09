import Foundation

/// 맥 언어 설정의 첫 언어가 한국어면 한국어, 그 밖에는 영어로 보인다
let isKorean = Locale.preferredLanguages.first?.hasPrefix("ko") ?? false
func L(_ ko: String, _ en: String) -> String { isKorean ? ko : en }

struct Service {
    let id: String
    let name: String
    let url: String
}

/// 사용자가 이름을 붙여 서비스 메뉴에 추가한 사이트
struct Site: Codable, Equatable {
    var name: String
    var url: String
}

enum Catalog {
    static let all: [Service] = [
        Service(id: "netflix",  name: "Netflix",      url: "https://www.netflix.com/"),
        Service(id: "tving",    name: "TVING",        url: "https://www.tving.com/"),
        Service(id: "wavve",    name: "Wavve",        url: "https://www.wavve.com/"),
        Service(id: "coupang",  name: L("쿠팡플레이", "Coupang Play"), url: "https://www.coupangplay.com/"),
        Service(id: "disney",   name: "Disney+",      url: "https://www.disneyplus.com/"),
        Service(id: "watcha",   name: L("왓챠", "Watcha"), url: "https://watcha.com/"),
        Service(id: "laftel",   name: L("라프텔", "Laftel"), url: "https://laftel.net/"),
        Service(id: "appletv",  name: "Apple TV+",    url: "https://tv.apple.com/"),
        Service(id: "youtube",  name: "YouTube",      url: "https://www.youtube.com/"),
        Service(id: "twitch",   name: "Twitch",       url: "https://www.twitch.tv/"),
        Service(id: "chzzk",    name: L("치지직", "CHZZK"), url: "https://chzzk.naver.com/"),
    ]

    /// 툴바 서비스 메뉴의 묶음 순서 (해외 / 국내 / 라이브·영상)
    static let groups: [[String]] = [
        ["netflix", "disney", "appletv"],
        ["tving", "wavve", "coupang", "watcha", "laftel"],
        ["youtube", "twitch", "chzzk"],
    ]

    static func service(id: String) -> Service? { all.first { $0.id == id } }

    /// 내 사이트를 서비스 형태로 (id는 "mine-순번")
    static var mine: [Service] {
        Prefs.mySites.enumerated().map { Service(id: "mine-\($0.offset)", name: $0.element.name, url: $0.element.url) }
    }

    /// 지금 주소에 맞는 항목. 내 사이트는 주소 앞부분이 가장 길게 맞는 것을 먼저 고른다.
    static func match(_ url: URL?) -> Service? {
        guard let cur = url.map({ comparable($0.absoluteString) }) else { return nil }
        let best = mine.filter { cur.hasPrefix(comparable($0.url)) }
            .max { comparable($0.url).count < comparable($1.url).count }
        return best ?? service(for: url)
    }

    private static func comparable(_ s: String) -> String {
        var t = s.lowercased()
        for p in ["https://", "http://"] where t.hasPrefix(p) { t.removeFirst(p.count) }
        if t.hasPrefix("www.") { t.removeFirst(4) }
        while t.hasSuffix("/") { t.removeLast() }
        return t
    }

    /// 주소의 호스트로 서비스를 찾는다. 서브도메인도 같은 서비스로 본다.
    static func service(for url: URL?) -> Service? {
        guard let host = url?.host?.lowercased() else { return nil }
        let h = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return all.first { s in
            guard var sh = URL(string: s.url)?.host?.lowercased() else { return false }
            if sh.hasPrefix("www.") { sh = String(sh.dropFirst(4)) }
            return h == sh || h.hasSuffix("." + sh)
        }
    }
}

enum Prefs {
    private static let d = UserDefaults.standard

    static var lastURL: String {
        get { d.string(forKey: "lastURL") ?? Catalog.all[0].url }
        set { d.set(newValue, forKey: "lastURL") }
    }
    static var opacity: Double {
        get { d.object(forKey: "opacity") as? Double ?? 1.0 }
        set { d.set(newValue, forKey: "opacity") }
    }
    static var pinned: Bool {
        get { d.object(forKey: "pinned") as? Bool ?? true }
        set { d.set(newValue, forKey: "pinned") }
    }
    static var aboveFullscreen: Bool {
        get { d.object(forKey: "aboveFullscreen") as? Bool ?? false }
        set { d.set(newValue, forKey: "aboveFullscreen") }
    }
    static var lockAspect: Bool {
        get { d.object(forKey: "lockAspect") as? Bool ?? false }
        set { d.set(newValue, forKey: "lockAspect") }
    }
    static var adBlock: Bool {
        get { d.object(forKey: "adBlock") as? Bool ?? true }
        set { d.set(newValue, forKey: "adBlock") }
    }
    static var mySites: [Site] {
        get {
            guard let data = d.data(forKey: "mySites") else { return [] }
            return (try? JSONDecoder().decode([Site].self, from: data)) ?? []
        }
        set { d.set(try? JSONEncoder().encode(newValue), forKey: "mySites") }
    }
    /// 주소 칸으로 연 주소. 최신이 앞, 최대 8개.
    static var recentURLs: [String] {
        get { d.stringArray(forKey: "recentURLs") ?? [] }
        set { d.set(Array(newValue.prefix(8)), forKey: "recentURLs") }
    }
    static func addRecent(_ url: String) {
        recentURLs = [url] + recentURLs.filter { $0 != url }
    }
    static var frame: String? {
        get { d.string(forKey: "frame") }
        set { d.set(newValue, forKey: "frame") }
    }
}
