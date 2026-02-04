import Cocoa
import Foundation

// MARK: - Data Models
struct PriceInfo {
    var price: String = "--"
    var yesterdayPrice: String = "--"
    var changeRate: String = ""      // 如 "+2.43%"
    var changeAmount: String = ""    // 如 "+26.93"

    var isUp: Bool {
        if let rate = Double(changeRate.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "+", with: "")) {
            return rate >= 0
        }
        return changeRate.hasPrefix("+") || (!changeRate.hasPrefix("-") && !changeRate.isEmpty)
    }
}

struct GoldPrices {
    var minsheng = PriceInfo()
    var icbc = PriceInfo()
    var zheshang = PriceInfo()
    var london = PriceInfo()
    var newyork = PriceInfo()
    var lastUpdate: Date?

    func priceInfo(for key: String) -> PriceInfo {
        switch key {
        case "minsheng": return minsheng
        case "icbc": return icbc
        case "zheshang": return zheshang
        case "london": return london
        case "newyork": return newyork
        default: return PriceInfo()
        }
    }
}

struct APIResponse: Codable {
    struct ResultData: Codable {
        struct Datas: Codable {
            let price: String?
            let yesterdayPrice: String?
            let upAndDownRate: String?
            let upAndDownAmt: String?
        }
        let datas: Datas?
    }
    let resultData: ResultData?
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

        prices.minsheng = await minsheng
        prices.icbc = await icbc
        prices.zheshang = await zheshang

        let intlPrices = await international
        prices.london = intlPrices.london
        prices.newyork = intlPrices.newyork

        prices.lastUpdate = Date()

        return prices
    }

    private func fetchMinsheng() async -> PriceInfo {
        var info = PriceInfo()
        guard let url = URL(string: "https://api.jdjygold.com/gw/generic/hj/h5/m/latestPrice") else { return info }
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(APIResponse.self, from: data)
            if let datas = response.resultData?.datas {
                info.price = datas.price ?? "--"
                info.yesterdayPrice = datas.yesterdayPrice ?? "--"
                info.changeRate = datas.upAndDownRate ?? ""
                info.changeAmount = datas.upAndDownAmt ?? ""
            }
        } catch {
            print("Minsheng fetch error: \(error)")
        }
        return info
    }

    private func fetchICBC() async -> PriceInfo {
        var info = PriceInfo()
        guard let url = URL(string: "https://api.jdjygold.com/gw2/generic/jrm/h5/m/icbcLatestPrice?productSku=2005453243") else { return info }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["reqData": ["productSku": "2005453243"]])
        do {
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(APIResponse.self, from: data)
            if let datas = response.resultData?.datas {
                info.price = datas.price ?? "--"
                info.yesterdayPrice = datas.yesterdayPrice ?? "--"
                info.changeRate = datas.upAndDownRate ?? ""
                info.changeAmount = datas.upAndDownAmt ?? ""
            }
        } catch {
            print("ICBC fetch error: \(error)")
        }
        return info
    }

    private func fetchZheshang() async -> PriceInfo {
        var info = PriceInfo()
        guard let url = URL(string: "https://api.jdjygold.com/gw2/generic/jrm/h5/m/stdLatestPrice?productSku=1961543816") else { return info }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["reqData": ["productSku": "1961543816"]])
        do {
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(APIResponse.self, from: data)
            if let datas = response.resultData?.datas {
                info.price = datas.price ?? "--"
                info.yesterdayPrice = datas.yesterdayPrice ?? "--"
                info.changeRate = datas.upAndDownRate ?? ""
                info.changeAmount = datas.upAndDownAmt ?? ""
            }
        } catch {
            print("Zheshang fetch error: \(error)")
        }
        return info
    }

    // 获取国际金价（伦敦金、纽约金）
    private func fetchInternationalGold() async -> (london: PriceInfo, newyork: PriceInfo) {
        var london = PriceInfo()
        var newyork = PriceInfo()

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
                        london = parseSinaData(line)
                    } else if line.contains("hf_GC") {
                        newyork = parseSinaData(line)
                    }
                }
            }
        } catch {
            print("International gold fetch error: \(error)")
        }

        return (london, newyork)
    }

    // 解析新浪数据：当前价,昨收,开盘,最高,最低,...,昨收2
    // 格式: "当前价,昨收,开盘,最高,最低,最低2,时间,昨收价,开盘价,..."
    private func parseSinaData(_ line: String) -> PriceInfo {
        var info = PriceInfo()
        guard let start = line.firstIndex(of: "\""),
              let end = line.lastIndex(of: "\"") else { return info }
        let content = String(line[line.index(after: start)..<end])
        let parts = content.components(separatedBy: ",")

        // 字段0: 当前价, 字段1: 昨收, 字段7: 昨收(备用)
        if parts.count > 7 {
            if let currentPrice = Double(parts[0]) {
                info.price = String(format: "%.2f", currentPrice)

                // 尝试获取昨收价（字段1或字段7）
                var yesterdayPrice: Double? = nil
                if let yp = Double(parts[1]), yp > 0 {
                    yesterdayPrice = yp
                } else if let yp = Double(parts[7]), yp > 0 {
                    yesterdayPrice = yp
                }

                if let yp = yesterdayPrice {
                    info.yesterdayPrice = String(format: "%.2f", yp)
                    let change = currentPrice - yp
                    let changePercent = (change / yp) * 100
                    let sign = change >= 0 ? "+" : ""
                    info.changeAmount = "\(sign)\(String(format: "%.2f", change))"
                    info.changeRate = "\(sign)\(String(format: "%.2f", changePercent))%"
                }
            }
        }
        return info
    }
}

// MARK: - Floating Window
class FloatingWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
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
    }

    func positionAtTopRight() {
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

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 4
        container.translatesAutoresizingMaskIntoConstraints = false
        container.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

        // Title - 国内金价
        let domesticTitle = createLabel("国内金价 (元/克)", size: 11, bold: true, color: .white)
        container.addArrangedSubview(domesticTitle)

        // 国内价格
        addPriceRow(to: container, key: "minsheng", name: "民生银行")
        addPriceRow(to: container, key: "icbc", name: "工商银行")
        addPriceRow(to: container, key: "zheshang", name: "浙商银行")

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(sep)
        sep.widthAnchor.constraint(equalToConstant: 200).isActive = true

        // Title - 国际金价
        let intlTitle = createLabel("国际金价 (美元/盎司)", size: 11, bold: true, color: .white)
        container.addArrangedSubview(intlTitle)

        // 国际价格
        addPriceRow(to: container, key: "london", name: "伦敦金　")
        addPriceRow(to: container, key: "newyork", name: "纽约金　")

        // Time
        timeLabel = createLabel("--:--:--", size: 10, bold: false, color: NSColor.lightGray)
        container.addArrangedSubview(timeLabel)

        addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor)
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

    private func addPriceRow(to stack: NSStackView, key: String, name: String) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.distribution = .fill
        row.spacing = 8

        let nameLabel = createLabel(name, size: 11, bold: false, color: NSColor.lightGray)
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)

        let priceLabel = createLabel("----", size: 12, bold: true, color: NSColor.systemYellow)
        priceLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        priceLabel.alignment = .right
        priceLabels[key] = priceLabel

        let changeLabel = createLabel("", size: 10, bold: false, color: NSColor.systemRed)
        changeLabel.setContentHuggingPriority(.required, for: .horizontal)
        changeLabels[key] = changeLabel

        row.addArrangedSubview(nameLabel)
        row.addArrangedSubview(priceLabel)
        row.addArrangedSubview(changeLabel)

        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 200).isActive = true

        stack.addArrangedSubview(row)
    }

    func updatePrices(_ prices: GoldPrices) {
        self.prices = prices

        updatePriceDisplay(key: "minsheng", info: prices.minsheng)
        updatePriceDisplay(key: "icbc", info: prices.icbc)
        updatePriceDisplay(key: "zheshang", info: prices.zheshang)
        updatePriceDisplay(key: "london", info: prices.london)
        updatePriceDisplay(key: "newyork", info: prices.newyork)

        if let lastUpdate = prices.lastUpdate {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            timeLabel.stringValue = "更新: " + formatter.string(from: lastUpdate)
        }
    }

    private func updatePriceDisplay(key: String, info: PriceInfo) {
        priceLabels[key]?.stringValue = info.price

        if !info.changeRate.isEmpty {
            let arrow = info.isUp ? "📈" : "📉"
            changeLabels[key]?.stringValue = "\(arrow)\(info.changeRate)"
            changeLabels[key]?.textColor = info.isUp ? NSColor.systemRed : NSColor.systemGreen  // 涨红跌绿
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

        let updateItem = NSMenuItem(title: "检查更新", action: #selector(checkForUpdate), keyEquivalent: "u")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func setupFloatingWindow() {
        floatingWindow = FloatingWindow()
        floatingContentView = FloatingContentView(frame: NSRect(x: 0, y: 0, width: 224, height: 195))
        floatingWindow?.contentView = floatingContentView
        floatingWindow?.setContentSize(NSSize(width: 224, height: 195))
        floatingWindow?.positionAtTopRight()
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
            let info = prices.priceInfo(for: statusBarPriceKey)
            button.title = "金: \(info.price)"
        }

        // Menu items - 国内
        minshengItem.title = formatMenuItem(name: "民生银行", info: prices.minsheng, unit: "元/克")
        icbcItem.title = formatMenuItem(name: "工商银行", info: prices.icbc, unit: "元/克")
        zheshangItem.title = formatMenuItem(name: "浙商银行", info: prices.zheshang, unit: "元/克")

        // Menu items - 国际
        londonItem.title = formatMenuItem(name: "伦敦金", info: prices.london, unit: "$/oz")
        newyorkItem.title = formatMenuItem(name: "纽约金", info: prices.newyork, unit: "$/oz")

        if let lastUpdate = prices.lastUpdate {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            lastUpdateItem.title = "更新时间: \(formatter.string(from: lastUpdate))"
        }

        // Floating window
        floatingContentView?.updatePrices(prices)
    }

    private func formatMenuItem(name: String, info: PriceInfo, unit: String) -> String {
        var text = "\(name): \(info.price) \(unit)"
        if !info.changeRate.isEmpty {
            let arrow = info.isUp ? "📈" : "📉"
            text += " \(arrow)\(info.changeRate)"
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

    @objc private func checkForUpdate() {
        Task { await performUpdateCheck() }
    }

    @MainActor
    private func performUpdateCheck() async {
        let currentVersion = "1.4.0"
        let repoURL = "https://api.github.com/repos/PiaoyangGuohai1/GoldPrice/releases/latest"

        guard let url = URL(string: repoURL) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tagName = json["tag_name"] as? String {
                let latestVersion = tagName.replacingOccurrences(of: "v", with: "")

                if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                    let alert = NSAlert()
                    alert.messageText = "发现新版本"
                    alert.informativeText = "当前版本: v\(currentVersion)\n最新版本: v\(latestVersion)\n\n是否前往下载？"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "前往下载")
                    alert.addButton(withTitle: "稍后再说")

                    if alert.runModal() == .alertFirstButtonReturn {
                        if let downloadURL = URL(string: "https://github.com/PiaoyangGuohai1/GoldPrice/releases/latest") {
                            NSWorkspace.shared.open(downloadURL)
                        }
                    }
                } else {
                    let alert = NSAlert()
                    alert.messageText = "已是最新版本"
                    alert.informativeText = "当前版本 v\(currentVersion) 已是最新。"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "好")
                    alert.runModal()
                }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "检查更新失败"
            alert.informativeText = "无法连接到服务器，请稍后再试。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
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
