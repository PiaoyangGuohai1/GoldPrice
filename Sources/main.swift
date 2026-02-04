import Cocoa
import Foundation

// MARK: - Data Models
struct GoldPrices {
    var minsheng: String = "--"
    var icbc: String = "--"
    var zheshang: String = "--"
    var london: String = "--"      // 伦敦金 (美元/盎司)
    var newyork: String = "--"     // 纽约金 (美元/盎司)
    var lastUpdate: Date?

    func price(for key: String) -> String {
        switch key {
        case "minsheng": return minsheng
        case "icbc": return icbc
        case "zheshang": return zheshang
        case "london": return london
        case "newyork": return newyork
        default: return "--"
        }
    }
}

struct APIResponse: Codable {
    struct ResultData: Codable {
        struct Datas: Codable {
            let price: String?
        }
        let datas: Datas?
    }
    let resultData: ResultData?
}

// MARK: - Price Tracker (记录今日基准价格)
class PriceTracker {
    static let shared = PriceTracker()

    private var baseDate: String = ""
    private var basePrices: [String: Double] = [:]

    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func recordPrice(key: String, price: Double) {
        let today = dateFormatter.string(from: Date())

        // 新的一天，重置基准价格
        if today != baseDate {
            baseDate = today
            basePrices.removeAll()
        }

        // 记录今日第一个价格作为基准
        if basePrices[key] == nil {
            basePrices[key] = price
        }
    }

    func getChange(key: String, currentPrice: Double) -> (percent: Double, isUp: Bool)? {
        guard let basePrice = basePrices[key], basePrice > 0 else { return nil }
        let change = (currentPrice - basePrice) / basePrice * 100
        return (change, change >= 0)
    }

    func formatChange(key: String, currentPrice: Double) -> String {
        guard let (percent, isUp) = getChange(key: key, currentPrice: currentPrice) else {
            return ""
        }
        let arrow = isUp ? "📈" : "📉"
        let sign = isUp ? "+" : ""
        return " \(arrow)\(sign)\(String(format: "%.2f", percent))%"
    }
}

// MARK: - Gold Price Service
class GoldPriceService {
    static let shared = GoldPriceService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        session = URLSession(configuration: config)
    }

    func fetchAllPrices() async -> GoldPrices {
        var prices = GoldPrices()

        async let minsheng = fetchMinsheng()
        async let icbc = fetchICBC()
        async let zheshang = fetchZheshang()
        async let international = fetchInternationalGold()

        prices.minsheng = await minsheng ?? "--"
        prices.icbc = await icbc ?? "--"
        prices.zheshang = await zheshang ?? "--"

        let intlPrices = await international
        prices.london = intlPrices.london
        prices.newyork = intlPrices.newyork

        prices.lastUpdate = Date()

        // 记录价格用于计算涨跌
        if let p = Double(prices.minsheng) { PriceTracker.shared.recordPrice(key: "minsheng", price: p) }
        if let p = Double(prices.icbc) { PriceTracker.shared.recordPrice(key: "icbc", price: p) }
        if let p = Double(prices.zheshang) { PriceTracker.shared.recordPrice(key: "zheshang", price: p) }
        if let p = Double(prices.london) { PriceTracker.shared.recordPrice(key: "london", price: p) }
        if let p = Double(prices.newyork) { PriceTracker.shared.recordPrice(key: "newyork", price: p) }

        return prices
    }

    private func fetchMinsheng() async -> String? {
        guard let url = URL(string: "https://api.jdjygold.com/gw/generic/hj/h5/m/latestPrice") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(APIResponse.self, from: data)
            return response.resultData?.datas?.price
        } catch {
            print("Minsheng fetch error: \(error)")
            return nil
        }
    }

    private func fetchICBC() async -> String? {
        guard let url = URL(string: "https://api.jdjygold.com/gw2/generic/jrm/h5/m/icbcLatestPrice?productSku=2005453243") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["reqData": ["productSku": "2005453243"]])
        do {
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(APIResponse.self, from: data)
            return response.resultData?.datas?.price
        } catch {
            print("ICBC fetch error: \(error)")
            return nil
        }
    }

    private func fetchZheshang() async -> String? {
        guard let url = URL(string: "https://api.jdjygold.com/gw2/generic/jrm/h5/m/stdLatestPrice?productSku=1961543816") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["reqData": ["productSku": "1961543816"]])
        do {
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(APIResponse.self, from: data)
            return response.resultData?.datas?.price
        } catch {
            print("Zheshang fetch error: \(error)")
            return nil
        }
    }

    // 获取国际金价（伦敦金、纽约金）
    private func fetchInternationalGold() async -> (london: String, newyork: String) {
        var london = "--"
        var newyork = "--"

        // 使用新浪财经 API
        guard let url = URL(string: "https://hq.sinajs.cn/list=hf_XAU,hf_GC") else {
            return (london, newyork)
        }

        var request = URLRequest(url: url)
        request.setValue("https://finance.sina.com.cn", forHTTPHeaderField: "Referer")

        do {
            let (data, _) = try await session.data(for: request)
            if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                let lines = text.components(separatedBy: ";")
                for line in lines {
                    if line.contains("hf_XAU") {
                        if let price = parsesSinaPrice(line) {
                            london = String(format: "%.2f", price)
                        }
                    } else if line.contains("hf_GC") {
                        if let price = parsesSinaPrice(line) {
                            newyork = String(format: "%.2f", price)
                        }
                    }
                }
            }
        } catch {
            print("International gold fetch error: \(error)")
        }

        return (london, newyork)
    }

    private func parsesSinaPrice(_ line: String) -> Double? {
        // 格式: var hq_str_hf_XAU="2625.55,2625.21,...";
        guard let start = line.firstIndex(of: "\""),
              let end = line.lastIndex(of: "\"") else { return nil }
        let content = String(line[line.index(after: start)..<end])
        let parts = content.components(separatedBy: ",")
        if let first = parts.first, let price = Double(first) {
            return price
        }
        return nil
    }
}

// MARK: - Floating Window
class FloatingWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Position at top-right of screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.maxX - self.frame.width - 20
            let y = screenRect.maxY - self.frame.height - 20
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}

class FloatingContentView: NSView {
    private var prices = GoldPrices()
    private var priceLabels: [String: NSTextField] = [:]
    private var changeLabels: [String: NSTextField] = [:]
    private var timeLabel: NSTextField!

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.85).cgColor

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 5
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

        // Title - 国内金价
        let domesticTitle = createLabel("国内金价 (元/克)", size: 11, bold: true, color: .white)
        stackView.addArrangedSubview(domesticTitle)

        // 国内价格
        addPriceRow(to: stackView, key: "minsheng", name: "民生", unit: "")
        addPriceRow(to: stackView, key: "icbc", name: "工商", unit: "")
        addPriceRow(to: stackView, key: "zheshang", name: "浙商", unit: "")

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(sep)
        sep.widthAnchor.constraint(equalToConstant: 216).isActive = true

        // Title - 国际金价
        let intlTitle = createLabel("国际金价 (美元/盎司)", size: 11, bold: true, color: .white)
        stackView.addArrangedSubview(intlTitle)

        // 国际价格
        addPriceRow(to: stackView, key: "london", name: "伦敦金", unit: "")
        addPriceRow(to: stackView, key: "newyork", name: "纽约金", unit: "")

        // Time
        timeLabel = createLabel("--:--:--", size: 10, bold: false, color: NSColor.lightGray)
        stackView.addArrangedSubview(timeLabel)

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    private func createLabel(_ text: String, size: CGFloat, bold: Bool, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        label.textColor = color
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        return label
    }

    private func addPriceRow(to stack: NSStackView, key: String, name: String, unit: String) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.distribution = .fill
        row.spacing = 4

        let nameLabel = createLabel(name, size: 11, bold: false, color: NSColor.lightGray)
        nameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let priceLabel = createLabel("--", size: 12, bold: true, color: NSColor.systemYellow)
        priceLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        priceLabels[key] = priceLabel

        let changeLabel = createLabel("", size: 10, bold: false, color: NSColor.systemRed)
        changeLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        changeLabels[key] = changeLabel

        row.addArrangedSubview(nameLabel)
        row.addArrangedSubview(priceLabel)
        row.addArrangedSubview(changeLabel)

        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 216).isActive = true

        stack.addArrangedSubview(row)
    }

    func updatePrices(_ prices: GoldPrices) {
        self.prices = prices

        updatePriceDisplay(key: "minsheng", priceStr: prices.minsheng)
        updatePriceDisplay(key: "icbc", priceStr: prices.icbc)
        updatePriceDisplay(key: "zheshang", priceStr: prices.zheshang)
        updatePriceDisplay(key: "london", priceStr: prices.london)
        updatePriceDisplay(key: "newyork", priceStr: prices.newyork)

        if let lastUpdate = prices.lastUpdate {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            timeLabel.stringValue = "更新: " + formatter.string(from: lastUpdate)
        }
    }

    private func updatePriceDisplay(key: String, priceStr: String) {
        priceLabels[key]?.stringValue = priceStr

        if let price = Double(priceStr),
           let (percent, isUp) = PriceTracker.shared.getChange(key: key, currentPrice: price) {
            let arrow = isUp ? "📈" : "📉"
            let sign = isUp ? "+" : ""
            changeLabels[key]?.stringValue = "\(arrow)\(sign)\(String(format: "%.2f", percent))%"
            changeLabels[key]?.textColor = isUp ? NSColor.systemRed : NSColor.systemGreen  // 涨红跌绿
        } else {
            changeLabels[key]?.stringValue = ""
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var prices = GoldPrices()
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 5.0

    // 状态栏显示选项
    private var statusBarPriceKey: String = "minsheng"
    private let priceOptions: [(key: String, name: String)] = [
        ("minsheng", "民生银行"),
        ("icbc", "工商银行"),
        ("zheshang", "浙商银行"),
        ("london", "伦敦金"),
        ("newyork", "纽约金")
    ]

    // Floating window
    private var floatingWindow: FloatingWindow?
    private var floatingContentView: FloatingContentView?
    private var showFloatingWindowItem: NSMenuItem!

    // Menu items
    private var minshengItem: NSMenuItem!
    private var icbcItem: NSMenuItem!
    private var zheshangItem: NSMenuItem!
    private var londonItem: NSMenuItem!
    private var newyorkItem: NSMenuItem!
    private var lastUpdateItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 读取保存的状态栏显示选项
        if let saved = UserDefaults.standard.string(forKey: "statusBarPriceKey") {
            statusBarPriceKey = saved
        }

        setupStatusItem()
        setupMenu()
        setupFloatingWindow()
        startRefreshing()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "金: --"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "金价监控", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Floating window toggle
        showFloatingWindowItem = NSMenuItem(title: "显示悬浮窗", action: #selector(toggleFloatingWindow), keyEquivalent: "f")
        showFloatingWindowItem.target = self
        menu.addItem(showFloatingWindowItem)
        menu.addItem(NSMenuItem.separator())

        // 国内金价
        let domesticHeader = NSMenuItem(title: "── 国内金价 ──", action: nil, keyEquivalent: "")
        domesticHeader.isEnabled = false
        menu.addItem(domesticHeader)

        minshengItem = NSMenuItem(title: "民生银行: --", action: nil, keyEquivalent: "")
        minshengItem.isEnabled = false
        menu.addItem(minshengItem)

        icbcItem = NSMenuItem(title: "工商银行: --", action: nil, keyEquivalent: "")
        icbcItem.isEnabled = false
        menu.addItem(icbcItem)

        zheshangItem = NSMenuItem(title: "浙商银行: --", action: nil, keyEquivalent: "")
        zheshangItem.isEnabled = false
        menu.addItem(zheshangItem)

        menu.addItem(NSMenuItem.separator())

        // 国际金价
        let intlHeader = NSMenuItem(title: "── 国际金价 ──", action: nil, keyEquivalent: "")
        intlHeader.isEnabled = false
        menu.addItem(intlHeader)

        londonItem = NSMenuItem(title: "伦敦金: --", action: nil, keyEquivalent: "")
        londonItem.isEnabled = false
        menu.addItem(londonItem)

        newyorkItem = NSMenuItem(title: "纽约金: --", action: nil, keyEquivalent: "")
        newyorkItem.isEnabled = false
        menu.addItem(newyorkItem)

        menu.addItem(NSMenuItem.separator())

        lastUpdateItem = NSMenuItem(title: "更新时间: --", action: nil, keyEquivalent: "")
        lastUpdateItem.isEnabled = false
        menu.addItem(lastUpdateItem)

        menu.addItem(NSMenuItem.separator())

        // 状态栏显示选项
        let statusBarItem = NSMenuItem(title: "状态栏显示", action: nil, keyEquivalent: "")
        let statusBarSubmenu = NSMenu()
        for option in priceOptions {
            let item = NSMenuItem(title: option.name, action: #selector(changeStatusBarPrice(_:)), keyEquivalent: "")
            item.representedObject = option.key
            item.target = self
            if option.key == statusBarPriceKey { item.state = .on }
            statusBarSubmenu.addItem(item)
        }
        statusBarItem.submenu = statusBarSubmenu
        menu.addItem(statusBarItem)

        // Refresh interval
        let intervalItem = NSMenuItem(title: "刷新间隔", action: nil, keyEquivalent: "")
        let intervalSubmenu = NSMenu()
        for seconds in [3, 5, 10, 30, 60] {
            let item = NSMenuItem(title: "\(seconds)秒", action: #selector(changeInterval(_:)), keyEquivalent: "")
            item.tag = seconds
            item.target = self
            if TimeInterval(seconds) == refreshInterval { item.state = .on }
            intervalSubmenu.addItem(item)
        }
        intervalItem.submenu = intervalSubmenu
        menu.addItem(intervalItem)

        let refreshItem = NSMenuItem(title: "立即刷新", action: #selector(manualRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func setupFloatingWindow() {
        floatingWindow = FloatingWindow()
        floatingContentView = FloatingContentView(frame: NSRect(x: 0, y: 0, width: 240, height: 200))
        floatingWindow?.contentView = floatingContentView
    }

    private func startRefreshing() {
        Task { await refreshPrices() }
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { await self?.refreshPrices() }
        }
    }

    @MainActor
    private func refreshPrices() async {
        prices = await GoldPriceService.shared.fetchAllPrices()
        updateUI()
    }

    @MainActor
    private func updateUI() {
        // Status bar - 只显示价格，不显示涨跌
        if let button = statusItem.button {
            let priceStr = prices.price(for: statusBarPriceKey)
            button.title = "金: \(priceStr)"
        }

        // Menu items - 国内
        minshengItem.title = formatMenuItem(key: "minsheng", name: "民生银行", priceStr: prices.minsheng, unit: "元/克")
        icbcItem.title = formatMenuItem(key: "icbc", name: "工商银行", priceStr: prices.icbc, unit: "元/克")
        zheshangItem.title = formatMenuItem(key: "zheshang", name: "浙商银行", priceStr: prices.zheshang, unit: "元/克")

        // Menu items - 国际
        londonItem.title = formatMenuItem(key: "london", name: "伦敦金", priceStr: prices.london, unit: "$/oz")
        newyorkItem.title = formatMenuItem(key: "newyork", name: "纽约金", priceStr: prices.newyork, unit: "$/oz")

        if let lastUpdate = prices.lastUpdate {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            lastUpdateItem.title = "更新时间: \(formatter.string(from: lastUpdate))"
        }

        // Floating window
        floatingContentView?.updatePrices(prices)
    }

    private func formatMenuItem(key: String, name: String, priceStr: String, unit: String) -> String {
        var text = "\(name): \(priceStr) \(unit)"
        if let price = Double(priceStr) {
            text += PriceTracker.shared.formatChange(key: key, currentPrice: price)
        }
        return text
    }

    @objc private func toggleFloatingWindow() {
        if floatingWindow?.isVisible == true {
            floatingWindow?.orderOut(nil)
            showFloatingWindowItem.title = "显示悬浮窗"
        } else {
            floatingWindow?.orderFront(nil)
            showFloatingWindowItem.title = "隐藏悬浮窗"
        }
    }

    @MainActor @objc private func changeStatusBarPrice(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }

        // 更新选中状态
        if let submenu = sender.menu {
            for item in submenu.items { item.state = .off }
        }
        sender.state = .on

        // 保存选项
        statusBarPriceKey = key
        UserDefaults.standard.set(key, forKey: "statusBarPriceKey")

        // 更新显示
        updateUI()
    }

    @objc private func changeInterval(_ sender: NSMenuItem) {
        if let submenu = sender.menu {
            for item in submenu.items { item.state = .off }
        }
        sender.state = .on
        refreshInterval = TimeInterval(sender.tag)
        startRefreshing()
    }

    @objc private func manualRefresh() {
        Task { await refreshPrices() }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
