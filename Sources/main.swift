// Veda — son penceresi kapanan uygulamayı kapatır.
// Polls instead of relying on AX notifications (which don't fire reliably on macOS 26).
//  - AXWindows (current Space, includes minimized) tells closed vs. minimized apart.
//  - CGWindowList + Space membership catches windows living on other Spaces / fullscreen.
//  - Hidden apps (Cmd+H) are never quit.
// Blacklist: ~/.config/veda/blacklist.txt (one bundle id per line, # comments)
import Cocoa
import ApplicationServices

@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSCopySpacesForWindows") func CGSCopySpacesForWindows(_ c: Int32, _ mask: Int32, _ wids: CFArray) -> Unmanaged<CFArray>?
@_silgen_name("CGSCopyManagedDisplaySpaces") func CGSCopyManagedDisplaySpaces(_ c: Int32) -> Unmanaged<CFArray>?

let pollInterval = 0.12
let grace = 0.25
let blacklistPath = NSString(string: "~/.config/veda/blacklist.txt").expandingTildeInPath
let defaultBlacklist: Set<String> = ["com.apple.finder", "com.hnc.Discord", "com.apple.ScreenSharing"]

func log(_ s: String) { FileHandle.standardError.write("\(Date()) \(s)\n".data(using: .utf8)!) }

final class Engine {
    let conn = CGSMainConnectionID()
    var hadWindows: [pid_t: Bool] = [:]
    var pendingSince: [pid_t: Date] = [:]
    var blacklist = defaultBlacklist
    var blacklistMTime: Date?
    var onQuit: ((NSRunningApplication) -> Void)?
    let me = getpid()

    func reloadBlacklistIfNeeded() {
        let m = (try? FileManager.default.attributesOfItem(atPath: blacklistPath))?[.modificationDate] as? Date
        guard m != blacklistMTime else { return }
        blacklistMTime = m
        var set = defaultBlacklist
        if let text = try? String(contentsOfFile: blacklistPath, encoding: .utf8) {
            for line in text.split(separator: "\n") {
                let s = line.split(separator: "#").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                if !s.isEmpty { set.insert(s) }
            }
        }
        blacklist = set
    }

    func currentSpaces() -> Set<Int> {
        guard let displays = CGSCopyManagedDisplaySpaces(conn)?.takeRetainedValue() as? [[String: Any]] else { return [] }
        var s = Set<Int>()
        for d in displays {
            if let cur = d["Current Space"] as? [String: Any], let id = cur["id64"] as? Int ?? cur["ManagedSpaceID"] as? Int { s.insert(id) }
        }
        return s
    }

    func axWindowCount(_ pid: pid_t) -> Int? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.1)
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &v) == .success,
              let wins = v as? [AXUIElement] else { return nil }
        var n = 0
        for w in wins {
            var sr: CFTypeRef?
            AXUIElementCopyAttributeValue(w, kAXSubroleAttribute as CFString, &sr)
            let sub = sr as? String ?? ""
            if sub == kAXStandardWindowSubrole as String || sub == "AXDialog" { n += 1 }
        }
        return n
    }

    func pidsWithWindowsOnOtherSpaces() -> Set<pid_t> {
        let cur = currentSpaces()
        guard let all = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        var out = Set<pid_t>()
        for w in all {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  let pid = w[kCGWindowOwnerPID as String] as? pid_t,
                  let id = w[kCGWindowNumber as String] as? UInt32,
                  (w[kCGWindowIsOnscreen as String] as? Bool) != true else { continue }
            let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            guard (b["Width"] ?? 0) >= 120, (b["Height"] ?? 0) >= 80 else { continue }
            let sp = CGSCopySpacesForWindows(conn, 7, [id] as CFArray)?.takeRetainedValue() as? [Int] ?? []
            if !sp.isEmpty && Set(sp).isDisjoint(with: cur) { out.insert(pid) }
        }
        return out
    }

    // Switching Spaces makes an app's windows vanish from AXWindows (it only lists the
    // current Space), which looks exactly like "last window closed". So any Space change
    // forgets what we knew and pauses briefly: an app must show a window on the new Space
    // before closing it there can quit it.
    var lastSpaces: Set<Int> = []
    var quietUntil = Date.distantPast

    func spaceChanged() {
        hadWindows.removeAll()
        pendingSince.removeAll()
        quietUntil = Date().addingTimeInterval(1.0)
    }

    func tick() {
        let spaces = currentSpaces()
        if spaces != lastSpaces {
            if !lastSpaces.isEmpty { spaceChanged() }
            lastSpaces = spaces
            return
        }
        if Date() < quietUntil { return }
        reloadBlacklistIfNeeded()
        var elsewhere: Set<pid_t>?   // computed lazily: only needed when an app looks windowless
        var alive = Set<pid_t>()
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let pid = app.processIdentifier
            alive.insert(pid)
            if pid == me || app.isTerminated || !app.isFinishedLaunching { continue }
            if let bid = app.bundleIdentifier, blacklist.contains(bid) { continue }
            if app.isHidden { pendingSince[pid] = nil; continue }
            guard let n = axWindowCount(pid) else { pendingSince[pid] = nil; continue }

            var has = n > 0
            if !has && hadWindows[pid] == true {
                if elsewhere == nil { elsewhere = pidsWithWindowsOnOtherSpaces() }
                has = elsewhere!.contains(pid)
            }
            if has {
                hadWindows[pid] = true
                pendingSince[pid] = nil
            } else if hadWindows[pid] == true {
                if let since = pendingSince[pid] {
                    if Date().timeIntervalSince(since) >= grace && currentSpaces() == lastSpaces {
                        log("quitting \(app.localizedName ?? "?") (\(app.bundleIdentifier ?? "?"))")
                        hadWindows[pid] = false
                        pendingSince[pid] = nil
                        app.terminate()
                        onQuit?(app)
                    }
                } else {
                    pendingSince[pid] = Date()
                }
            }
        }
        hadWindows = hadWindows.filter { alive.contains($0.key) }
        pendingSince = pendingSince.filter { alive.contains($0.key) }
    }
}

struct Recent { let name: String; let url: URL?; let icon: NSImage?; let date: Date }

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let engine = Engine()
    var item: NSStatusItem!
    var recents: [Recent] = []
    var timer: Timer?
    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enabled"); updateIcon() }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu(); menu.delegate = self; item.menu = menu
        updateIcon()

        engine.onQuit = { [weak self] app in
            guard let self else { return }
            let icon = app.icon.map { i -> NSImage in let c = i.copy() as! NSImage; c.size = NSSize(width: 16, height: 16); return c }
            self.recents.insert(Recent(name: app.localizedName ?? "?", url: app.bundleURL, icon: icon, date: Date()), at: 0)
            if self.recents.count > 8 { self.recents.removeLast() }
        }

        if !AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) {
            log("waiting for Accessibility permission…")
        }
        log("Veda started")
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.engine.spaceChanged()
        }
        timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self, self.enabled, AXIsProcessTrusted() else { return }
            self.engine.tick()
        }
        timer!.tolerance = 0.03
        RunLoop.main.add(timer!, forMode: .common)
    }

    func updateIcon() {
        let name = enabled ? "hand.wave.fill" : "hand.wave"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Veda")
        img?.isTemplate = true
        item?.button?.image = img
        item?.button?.appearsDisabled = !enabled
        item?.button?.toolTip = enabled ? "Veda — açık" : "Veda — duraklatıldı"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: "Veda", action: nil, keyEquivalent: ""); title.isEnabled = false
        menu.addItem(title)
        if !AXIsProcessTrusted() {
            let w = NSMenuItem(title: "⚠️ Erişilebilirlik izni gerekli…", action: #selector(openAX), keyEquivalent: ""); w.target = self
            menu.addItem(w)
        }
        let t = NSMenuItem(title: "Etkin", action: #selector(toggle), keyEquivalent: "e"); t.target = self
        t.state = enabled ? .on : .off
        menu.addItem(t)
        menu.addItem(.separator())

        let header = NSMenuItem(title: recents.isEmpty ? "Henüz kapatılan uygulama yok" : "Son kapatılanlar (tıkla → yeniden aç)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let fmt = RelativeDateTimeFormatter(); fmt.locale = Locale(identifier: "tr_TR"); fmt.unitsStyle = .short
        for (i, r) in recents.enumerated() {
            let m = NSMenuItem(title: "\(r.name)  ·  \(fmt.localizedString(for: r.date, relativeTo: Date()))", action: #selector(reopen(_:)), keyEquivalent: "")
            m.target = self; m.tag = i; m.image = r.icon
            menu.addItem(m)
        }
        menu.addItem(.separator())

        if let front = NSWorkspace.shared.frontmostApplication, front.activationPolicy == .regular,
           let bid = front.bundleIdentifier, front.processIdentifier != getpid() {
            let listed = engine.blacklist.contains(bid)
            let b = NSMenuItem(title: listed ? "\(front.localizedName ?? bid) kapatılmıyor ✓" : "\(front.localizedName ?? bid) uygulamasını hiç kapatma",
                               action: listed ? nil : #selector(blacklistFront(_:)), keyEquivalent: "")
            b.target = self; b.representedObject = bid; b.isEnabled = !listed
            menu.addItem(b)
        }
        let e = NSMenuItem(title: "Kara listeyi düzenle…", action: #selector(editBlacklist), keyEquivalent: ","); e.target = self
        menu.addItem(e)
        let l = NSMenuItem(title: "Kayıtları göster", action: #selector(showLog), keyEquivalent: ""); l.target = self
        menu.addItem(l)
        menu.addItem(.separator())
        let q = NSMenuItem(title: "Veda'dan çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(q)
    }

    @objc func toggle() { enabled.toggle() }
    @objc func openAX() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func reopen(_ s: NSMenuItem) {
        guard s.tag < recents.count, let url = recents[s.tag].url else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
    func ensureBlacklistFile() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: blacklistPath) {
            try? fm.createDirectory(atPath: (blacklistPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            let header = "# Veda bu uygulamaları hiç kapatmaz. Her satıra bir bundle id.\n# Finder ve Discord her zaman hariç tutulur.\n"
            try? header.write(toFile: blacklistPath, atomically: true, encoding: .utf8)
        }
    }
    @objc func blacklistFront(_ s: NSMenuItem) {
        guard let bid = s.representedObject as? String else { return }
        ensureBlacklistFile()
        if let h = FileHandle(forWritingAtPath: blacklistPath) { h.seekToEndOfFile(); h.write("\(bid)\n".data(using: .utf8)!); h.closeFile() }
        engine.blacklistMTime = nil
    }
    @objc func editBlacklist() {
        ensureBlacklistFile()
        NSWorkspace.shared.open([URL(fileURLWithPath: blacklistPath)], withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"), configuration: NSWorkspace.OpenConfiguration())
    }
    @objc func showLog() {
        NSWorkspace.shared.open(URL(fileURLWithPath: NSString(string: "~/Library/Logs/veda.log").expandingTildeInPath))
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
