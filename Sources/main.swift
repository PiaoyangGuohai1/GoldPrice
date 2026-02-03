import Cocoa
import Foundation

// MARK: - Data Models
struct GoldPrices {
    var minsheng: String = "--"
    var icbc: String = "--"
    var zheshang: String = "--"
    var xau: String = "--"
    var lastUpdate: Date?
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

        prices.minsheng = await minsheng ?? "--"
        prices.icbc = await icbc ?? "--"
        prices.zheshang = await zheshang ?? "--"
        prices.lastUpdate = Date()

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
}

// MARK: - Floating Window
class FloatingWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 140),
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
    private var labels: [String: NSTextField] = [:]
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
        stackView.spacing = 6
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)

        // Title
        let title = createLabel("京东金价", size: 13, bold: true, color: .white)
        stackView.addArrangedSubview(title)

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(sep)
        sep.widthAnchor.constraint(equalToConstant: 172).isActive = true

        // Price rows
        labels["minsheng"] = addPriceRow(to: stackView, name: "民生", price: "--")
        labels["icbc"] = addPriceRow(to: stackView, name: "工商", price: "--")
        labels["zheshang"] = addPriceRow(to: stackView, name: "浙商", price: "--")

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

    private func addPriceRow(to stack: NSStackView, name: String, price: String) -> NSTextField {
        let row = NSStackView()
        row.orientation = .horizontal
        row.distribution = .fill
        row.spacing = 8

        let nameLabel = createLabel(name, size: 12, bold: false, color: NSColor.lightGray)
        nameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let priceLabel = createLabel(price, size: 13, bold: true, color: NSColor.systemYellow)
        priceLabel.alignment = .right
        priceLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)

        row.addArrangedSubview(nameLabel)
        row.addArrangedSubview(priceLabel)

        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 172).isActive = true

        stack.addArrangedSubview(row)
        return priceLabel
    }

    func updatePrices(_ prices: GoldPrices) {
        self.prices = prices
        labels["minsheng"]?.stringValue = prices.minsheng + " 元"
        labels["icbc"]?.stringValue = prices.icbc + " 元"
        labels["zheshang"]?.stringValue = prices.zheshang + " 元"

        if let lastUpdate = prices.lastUpdate {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            timeLabel.stringValue = "更新: " + formatter.string(from: lastUpdate)
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var prices = GoldPrices()
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 5.0

    // Floating window
    private var floatingWindow: FloatingWindow?
    private var floatingContentView: FloatingContentView?
    private var showFloatingWindowItem: NSMenuItem!

    // Menu items
    private var minshengItem: NSMenuItem!
    private var icbcItem: NSMenuItem!
    private var zheshangItem: NSMenuItem!
    private var lastUpdateItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()
        setupFloatingWindow()
        startRefreshing()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "金价: --"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "京东金价监控", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Floating window toggle
        showFloatingWindowItem = NSMenuItem(title: "显示悬浮窗", action: #selector(toggleFloatingWindow), keyEquivalent: "f")
        showFloatingWindowItem.target = self
        menu.addItem(showFloatingWindowItem)
        menu.addItem(NSMenuItem.separator())

        // Price items
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

        lastUpdateItem = NSMenuItem(title: "更新时间: --", action: nil, keyEquivalent: "")
        lastUpdateItem.isEnabled = false
        menu.addItem(lastUpdateItem)

        menu.addItem(NSMenuItem.separator())

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
        floatingContentView = FloatingContentView(frame: NSRect(x: 0, y: 0, width: 200, height: 140))
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
        // Status bar
        if let button = statusItem.button {
            let displayPrice = prices.minsheng != "--" ? prices.minsheng : "--"
            button.title = "金: \(displayPrice)"
        }

        // Menu items
        minshengItem.title = "民生银行: \(prices.minsheng) 元/克"
        icbcItem.title = "工商银行: \(prices.icbc) 元/克"
        zheshangItem.title = "浙商银行: \(prices.zheshang) 元/克"

        if let lastUpdate = prices.lastUpdate {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            lastUpdateItem.title = "更新时间: \(formatter.string(from: lastUpdate))"
        }

        // Floating window
        floatingContentView?.updatePrices(prices)
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
