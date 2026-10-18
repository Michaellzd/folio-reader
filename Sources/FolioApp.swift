import SwiftUI
import AppKit

@main
struct FolioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var state = ReaderState.shared
    var body: some Scene {
        Window("Folio", id: "reader") {
            ReaderView(state: state)
                .frame(minWidth: 620, minHeight: 440)
                .preferredColorScheme(state.dark ? .dark : .light)
                .environment(\.locale, Locale(identifier: state.language.rawValue))
                .onAppear { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 1120, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(state.t("打开 EPUB…"), action: state.chooseFile).keyboardShortcut("o")
            }
            CommandGroup(after: .saveItem) {
                Button(state.t(state.noteEditor ? "保存笔记" : "保存书签")) { if state.noteEditor { state.saveNote() } else { state.saveBookmark() } }.keyboardShortcut("s").disabled(!state.pageReady)
                Button(state.t("添加笔记"), action: state.newNote).keyboardShortcut("n", modifiers: [.command, .shift]).disabled(!state.pageReady)
            }
            CommandMenu(state.t("阅读")) {
                Button(state.t("上一节")) { state.turn(-1) }.keyboardShortcut(.leftArrow, modifiers: .command).disabled(state.book == nil || state.chapterIndex == 0)
                Button(state.t("下一节")) { state.turn(1) }.keyboardShortcut(.rightArrow, modifiers: .command).disabled(state.book == nil || state.chapterIndex >= (state.book?.spine.count ?? 0) - 1)
                Divider()
                Button(state.t(state.sidebar ? "隐藏目录" : "显示目录")) { state.sidebar.toggle() }.keyboardShortcut("s", modifiers: [.command, .control])
                Button(state.t("放大字号")) { state.fontSize = min(32, state.fontSize + 2) }.keyboardShortcut("+")
                Button(state.t("缩小字号")) { state.fontSize = max(14, state.fontSize - 2) }.keyboardShortcut("-")
                Button(state.t(state.dark ? "浅色外观" : "深色外观")) { state.dark.toggle() }.keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let path = CommandLine.arguments.dropFirst().first(where: { $0.lowercased().hasSuffix(".epub") }) {
            ReaderState.shared.open(URL(fileURLWithPath: path))
        } else if let path = UserDefaults.standard.string(forKey: "lastBook"), FileManager.default.fileExists(atPath: path) {
            DispatchQueue.main.async {
                if ReaderState.shared.book == nil && !ReaderState.shared.isLoading { ReaderState.shared.open(URL(fileURLWithPath: path)) }
            }
        }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first { ReaderState.shared.open(url) }
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) {
        ReaderState.shared.savePosition()
        if let root = ReaderState.shared.book?.root { try? FileManager.default.removeItem(at: root) }
    }
}

struct ReaderView: View {
    @ObservedObject var state: ReaderState
    @State private var dropping = false
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle().fill(state.muted.opacity(0.15)).frame(height: 1)
            if let book = state.book {
                HStack(spacing: 0) {
                    if state.sidebar {
                        VStack(spacing: 0) {
                            Picker("", selection: $state.showAnnotations) {
                                Text(state.t("目录")).tag(false)
                                Text(state.t("书签与笔记")).tag(true)
                            }.pickerStyle(.segmented).labelsHidden().padding(14)
                            if state.showAnnotations { MarksView(state: state) }
                            else { contents(book) }
                        }
                            .frame(width: 270)
                        Rectangle().fill(state.muted.opacity(0.15)).frame(width: 1)
                    }
                    VStack(spacing: 0) {
                        if let message = state.storageError {
                            Text(state.t(message)).font(.system(size: 12)).padding(12).frame(maxWidth: .infinity)
                                .background(state.accent.opacity(0.15)).accessibilityAddTraits(.updatesFrequently)
                        }
                        if let message = state.webError {
                            ContentUnavailableView { Label(state.t("暂时无法显示"), systemImage: "doc.text") } description: { Text(state.t(message)) }
                        } else {
                            BookWebView(state: state)
                                .overlay(alignment: .bottom) {
                                    if state.selection != nil { SelectionToolbar(state: state).padding(16) }
                                }
                        }
                        footer(book)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else { emptyState }
        }
        .background(state.paper)
        .foregroundStyle(state.ink)
        .tint(state.accent)
        .overlay {
            if state.isLoading {
                ZStack {
                    state.paper.opacity(0.94)
                    VStack(spacing: 16) {
                        ProgressView().controlSize(.small)
                        Text(state.t("正在打开电子书…")).font(.system(size: 14)).foregroundStyle(state.muted)
                    }
                }
            }
            if dropping {
                RoundedRectangle(cornerRadius: 12).strokeBorder(state.accent, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .padding(10).background(state.paper.opacity(0.7))
                    .overlay(Text(state.t("松开，开始阅读")).font(.title2).foregroundStyle(state.ink))
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
            guard let item = providers.first else { return false }
            _ = item.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in state.open(url) } }
            }
            return true
        }
        .alert(state.t("无法打开这本书"), isPresented: Binding(get: { state.error != nil }, set: { if !$0 { state.error = nil } })) {
            Button(state.t("重新选择…"), action: state.chooseFile)
            Button(state.t("好"), role: .cancel) { state.error = nil }
        } message: { Text(state.t(state.error ?? "")) }
        .sheet(isPresented: $state.noteEditor) { NoteEditorView(state: state) }
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            // Leave room for the native traffic-light controls in a hidden-titlebar window.
            Color.clear.frame(width: 64, height: 1)
            if state.book != nil {
                tool(state.t("目录"), icon: "sidebar.left") { state.sidebar.toggle() }
            }
            Button(action: state.chooseFile) { Label(state.t("打开"), systemImage: "folder") }
                .buttonStyle(.plain).font(.system(size: 13)).help(state.t("打开 EPUB") + " (⌘O)")
                .disabled(state.isLoading)
            Spacer(minLength: 20)
            if state.book != nil {
                tool(state.t(state.saveFeedback ? "已保存" : "保存书签"), icon: state.saveFeedback ? "bookmark.fill" : "bookmark") { state.saveBookmark() }
                    .disabled(!state.pageReady)
                tool(state.t("添加笔记"), icon: "square.and.pencil") { state.newNote() }.disabled(!state.pageReady)
                tool(state.t("书签与笔记"), icon: "text.book.closed") { state.sidebar = true; state.showAnnotations.toggle() }
            }
            if let book = state.book {
                Text(book.title).font(.system(size: 12, weight: .medium)).foregroundStyle(state.muted)
                    .lineLimit(1).truncationMode(.middle)
            } else {
                Text(state.t("Folio")).font(.system(size: 13, weight: .medium)).foregroundStyle(state.muted)
            }
            Spacer(minLength: 20)
            tool(state.t("阅读外观"), icon: "textformat.size") { state.appearancePanel.toggle() }
                .popover(isPresented: $state.appearancePanel, arrowEdge: .bottom) { appearance }
        }
        .padding(.horizontal, 20).frame(height: 56)
    }

    private func tool(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 15)).frame(width: 30, height: 30).contentShape(Rectangle()) }
            .buttonStyle(.plain).help(title).accessibilityLabel(title)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            BookMarkDrawing().stroke(state.accent, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 70, height: 70).padding(.bottom, 30).accessibilityHidden(true)
            Text(state.t("翻开一本好书。"))
                .font(.custom(state.language == .chinese || state.language == .japanese ? "Songti SC" : "Georgia", size: state.language == .spanish ? 30 : 36)).tracking(0).multilineTextAlignment(.center).padding(.horizontal, 30).padding(.bottom, 14)
            Text(state.t("把 EPUB 拖到这里，留一点时间给阅读。"))
                .font(.system(size: 14)).foregroundStyle(state.muted).padding(.bottom, 30)
            Button(action: state.chooseFile) {
                Label(state.t("打开 EPUB"), systemImage: "plus").font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(state.accent, in: RoundedRectangle(cornerRadius: 7))
                    .foregroundStyle(state.dark ? Color(hex: 0x20221F) : .white)
            }
            .buttonStyle(.plain).keyboardShortcut(.return, modifiers: [])
            Text("⌘ O").font(.system(size: 11)).foregroundStyle(state.muted).padding(.top, 12)
            if let recent = UserDefaults.standard.string(forKey: "lastBook"), FileManager.default.fileExists(atPath: recent) {
                Button { state.open(URL(fileURLWithPath: recent)) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(state.t("继续阅读") + " · " + URL(fileURLWithPath: recent).deletingPathExtension().lastPathComponent).lineLimit(1)
                    }
                    .font(.system(size: 12)).foregroundStyle(state.muted).frame(maxWidth: 420)
                }.buttonStyle(.plain).padding(.top, 32)
            }
            Spacer()
            Text("FOLIO").font(.system(size: 10, weight: .medium)).tracking(3)
                .foregroundStyle(state.muted).padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func contents(_ book: EPUBBook) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                Text(book.title).font(.custom("Georgia", size: 22)).lineLimit(4).fixedSize(horizontal: false, vertical: true)
                if !book.author.isEmpty { Text(book.author).font(.system(size: 12)).foregroundStyle(state.muted).lineLimit(2) }
            }.padding(.horizontal, 25).padding(.top, 30).padding(.bottom, 25)
            Text(state.t("目录")).font(.system(size: 11, weight: .semibold)).foregroundStyle(state.muted)
                .padding(.horizontal, 25).padding(.bottom, 12)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(book.chapters) { chapter in
                            Button { state.navigate(chapter.url) } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(chapter.title).font(.system(size: 12, weight: state.selectedChapter == chapter.id ? .medium : .regular))
                                        .lineSpacing(4).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                                    if state.selectedChapter == chapter.id {
                                        Circle().fill(state.accent).frame(width: 5, height: 5).padding(.top, 6)
                                    }
                                }
                                .padding(.leading, 12 + CGFloat(min(chapter.depth, 3)) * 12).padding(.trailing, 12).padding(.vertical, 10)
                                .background(state.selectedChapter == chapter.id ? state.accent.opacity(0.12) : .clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).id(chapter.id)
                            .accessibilityAddTraits(state.selectedChapter == chapter.id ? .isSelected : [])
                        }
                    }.padding(.horizontal, 13).padding(.bottom, 24)
                }
                .onChange(of: state.selectedChapter) { _, id in if let id { proxy.scrollTo(id, anchor: .center) } }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(state.dark ? Color(hex: 0x252722) : Color(hex: 0xF0EDE5))
    }

    private func footer(_ book: EPUBBook) -> some View {
        GeometryReader { geometry in
        HStack {
            Button { state.turn(-1) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                    if geometry.size.width > 520 { Text(state.t("上一节")) }
                }
            }.accessibilityLabel(state.t("上一节"))
                .disabled(state.chapterIndex == 0).help(state.t("上一节") + " (⌘←)")
            Spacer()
            HStack(spacing: 6) {
                Text(state.sectionLabel(book.spine.count)).monospacedDigit().lineLimit(1)
                if state.lastSavedAt != nil && state.storageError == nil {
                    Image(systemName: "checkmark").accessibilityLabel(state.t("进度已自动保存"))
                }
            }.help(state.t("进度自动保存在本机，下次启动继续阅读。"))
            Spacer()
            Button { state.turn(1) } label: {
                HStack(spacing: 5) {
                    if geometry.size.width > 520 { Text(state.t("下一节")) }
                    Image(systemName: "chevron.right")
                }
            }.accessibilityLabel(state.t("下一节"))
                .disabled(state.chapterIndex == book.spine.count - 1).help(state.t("下一节") + " (⌘→)")
        }
        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(state.muted)
        .padding(.horizontal, 28).frame(height: 44)
        .overlay(alignment: .top) { Rectangle().fill(state.muted.opacity(0.12)).frame(height: 1) }
        }.frame(height: 44)
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(state.t("阅读外观")).font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            HStack {
                Text(state.t("字号")).font(.system(size: 12))
                Spacer()
                Button { state.fontSize = max(14, state.fontSize - 2) } label: { Image(systemName: "minus").frame(width: 22, height: 22) }.disabled(state.fontSize <= 14).accessibilityLabel(state.t("缩小字号"))
                Text("\(Int(state.fontSize))").font(.system(size: 12)).monospacedDigit().frame(width: 26)
                Button { state.fontSize = min(32, state.fontSize + 2) } label: { Image(systemName: "plus").frame(width: 22, height: 22) }.disabled(state.fontSize >= 32).accessibilityLabel(state.t("放大字号"))
            }
            Picker(state.t("界面语言"), selection: $state.language) {
                ForEach(AppLanguage.allCases) { language in Text(language.name).tag(language) }
            }.pickerStyle(.menu)
            Picker(state.t("纸张"), selection: $state.dark) {
                Text(state.t("日间")).tag(false)
                Text(state.t("夜间")).tag(true)
            }.pickerStyle(.segmented)
        }.padding(22).frame(width: 290)
    }
}

struct BookMarkDrawing: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.24))
        p.addCurve(to: CGPoint(x: w * 0.08, y: h * 0.15), control1: CGPoint(x: w * 0.32, y: h * 0.09), control2: CGPoint(x: w * 0.18, y: h * 0.1))
        p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.76))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.86), control1: CGPoint(x: w * 0.26, y: h * 0.7), control2: CGPoint(x: w * 0.36, y: h * 0.74))
        p.addCurve(to: CGPoint(x: w * 0.92, y: h * 0.76), control1: CGPoint(x: w * 0.64, y: h * 0.74), control2: CGPoint(x: w * 0.74, y: h * 0.7))
        p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.15))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.24), control1: CGPoint(x: w * 0.82, y: h * 0.1), control2: CGPoint(x: w * 0.68, y: h * 0.09))
        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.86))
        return p
    }
}
