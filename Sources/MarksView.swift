import SwiftUI

struct MarksView: View {
    @ObservedObject var state: ReaderState
    @State private var pendingRemoval: ReadingMark?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(state.t("书签与笔记")).font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: state.newNote) { Image(systemName: "plus") }
                    .buttonStyle(.plain).help(state.t("添加笔记")).accessibilityLabel(state.t("添加笔记"))
                    .disabled(!state.pageReady)
            }.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 20)
            if state.marks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(state.t("还没有书签或笔记")).font(.system(size: 13, weight: .medium))
                    Text(state.t("点顶部的书签保存位置，或选中文字后添加笔记。"))
                        .font(.system(size: 12)).foregroundStyle(state.muted).lineSpacing(5)
                }.padding(.horizontal, 22)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(state.marks) { mark in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: mark.kind == .bookmark ? "bookmark" : mark.kind == .highlight ? "highlighter" : "note.text")
                                        .foregroundStyle(mark.color.map { Color(hex: $0.hex) } ?? state.accent).accessibilityHidden(true)
                                    Text(state.t(mark.kind == .bookmark ? "书签" : mark.kind == .highlight ? "标注" : "笔记")).font(.system(size: 11, weight: .semibold))
                                    Spacer()
                                    Menu {
                                        Button(state.t("跳到这里")) { state.jump(to: mark) }
                                        if mark.kind != .bookmark { Button(state.t(mark.kind == .highlight ? "添加笔记" : "编辑笔记")) { state.editNote(mark) } }
                                        Button(state.t("删除"), role: .destructive) { pendingRemoval = mark }
                                    } label: { Image(systemName: "ellipsis") }
                                    .menuStyle(.borderlessButton).fixedSize().accessibilityLabel(state.t("更多操作"))
                                }
                                Button { state.jump(to: mark) } label: {
                                    VStack(alignment: .leading, spacing: 9) {
                                        Text(mark.section).font(.system(size: 12, weight: .medium)).lineLimit(2)
                                        if !mark.quote.isEmpty {
                                            Text(mark.quote).font(.system(size: 12)).italic().foregroundStyle(state.muted).lineLimit(3)
                                        }
                                        if mark.kind == .note { Text(mark.text).font(.system(size: 13)).lineSpacing(4).lineLimit(5) }
                                        Text(mark.createdAt, style: .date).font(.system(size: 10)).foregroundStyle(state.muted)
                                    }.multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).help(state.t("跳到这里"))
                            }.padding(.horizontal, 22).padding(.vertical, 18)
                            Divider().padding(.horizontal, 22)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(state.dark ? Color(hex: 0x252722) : Color(hex: 0xF0EDE5))
        .alert(state.t("删除这条记录？"), isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })) {
            Button(state.t("取消"), role: .cancel) { pendingRemoval = nil }
            Button(state.t("删除"), role: .destructive) {
                if let mark = pendingRemoval { state.removeMark(mark) }
                pendingRemoval = nil
            }
        }
    }
}

struct NoteEditorView: View {
    @ObservedObject var state: ReaderState
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(state.t("笔记")).font(.system(size: 20, weight: .semibold))
            Text(state.t("笔记保存在本机，关联到当前阅读位置。"))
                .font(.system(size: 12)).foregroundStyle(state.muted)
            if !state.draftQuote.isEmpty {
                HStack(spacing: 10) {
                    Text(state.t("标注颜色")).font(.system(size: 12))
                    ForEach(HighlightColor.allCases) { color in
                        Button { state.draftColor = color } label: {
                            Circle().fill(Color(hex: color.hex)).frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(state.draftColor == color ? state.ink : .clear, lineWidth: 2))
                        }.buttonStyle(.plain).accessibilityLabel(state.t(color.label))
                            .accessibilityAddTraits(state.draftColor == color ? .isSelected : [])
                    }
                }
                ScrollView { Text(state.draftQuote).font(.system(size: 13)).italic().frame(maxWidth: .infinity, alignment: .leading).padding(12) }
                    .frame(maxHeight: 90).background(state.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            TextEditor(text: $state.draftText).font(.system(size: 14)).frame(minHeight: 160)
                .padding(8).background(state.paper, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(state.muted.opacity(0.25)))
                .accessibilityLabel(state.t("笔记内容"))
            if let error = state.storageError { Text(state.t(error)).font(.system(size: 12)).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(state.t("取消")) { state.noteEditor = false }.keyboardShortcut(.cancelAction)
                Button(state.t("保存笔记"), action: state.saveNote).keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(state.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(26).frame(width: 480).background(state.paper).foregroundStyle(state.ink)
            .interactiveDismissDisabled()
    }
}

struct SelectionToolbar: View {
    @ObservedObject var state: ReaderState
    var body: some View {
        HStack(spacing: 12) {
            Text(state.t("标注")).font(.system(size: 12, weight: .medium))
            ForEach(HighlightColor.allCases) { color in
                Button { state.highlight(color) } label: {
                    Circle().fill(Color(hex: color.hex)).frame(width: 22, height: 22)
                }.buttonStyle(.plain).help(state.t(color.label)).accessibilityLabel(state.t(color.label))
            }
            Divider().frame(height: 20)
            Button(state.t("添加笔记"), action: state.newNote).buttonStyle(.plain).font(.system(size: 12))
        }.padding(.horizontal, 16).padding(.vertical, 12)
            .background(state.paper, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(state.muted.opacity(0.25)))
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    }
}
