# Folio · 书页

A small, quiet EPUB reader for Mac. Open a book and start reading.

Native SwiftUI and WebKit. Local files, no account, no server, no third-party runtime dependencies.

![Folio reading window](docs/reading.jpg)

## Download and install

[Download Folio for Mac](https://github.com/Michaellzd/folio-reader/releases/latest/download/Folio-macOS-universal.zip) · [All releases](https://github.com/Michaellzd/folio-reader/releases)

Choose **Folio-macOS-universal.zip** under release assets. The source-code archives are for developers. Requires **macOS 14 or later**; the universal app contains Apple Silicon and Intel builds. Apple Silicon is tested locally; Intel is cross-compiled.

1. Download and unzip the application archive.
2. Drag **书页.app** to Applications and open it.
3. Click **Open EPUB**, press **⌘O**, or drop an EPUB onto the window. Finder's **Open With → 书页** also works.

The current release uses an ad hoc signature and is **not Apple-notarized**. For a downloaded app, macOS may require **System Settings → Privacy & Security → Open Anyway** after the first launch attempt. See [Apple's instructions](https://support.apple.com/en-us/102445).

## Reading

- EPUB 2 and EPUB 3, including contents, nested sections, anchors, local images, and chapter navigation.
- A collapsible contents sidebar, adjustable text size, and day/night paper.
- Saved reading position per file, plus a shortcut to the last opened book.
- **简体中文 · English · 日本語 · Español**. The interface follows your system language on first launch. Use **Reading appearance → Interface language** to change it; the choice is saved locally.

The book stays in its original language. DRM-encrypted books, ZIP64 archives, fixed-layout reproduction, vertical typesetting, and interactive EPUB scripts are outside this first version. This is a reflowable text reader, so publisher layouts can look different. Remote links and remote book resources are blocked.

| Shortcut | Action |
| --- | --- |
| ⌘O | Open EPUB |
| ⌘← / ⌘→ | Previous / next spine section |
| ⌃⌘S | Show / hide contents |
| ⌘+ / ⌘− | Increase / decrease text size |
| ⇧⌘D | Toggle day / night |

## 中文

书页是一款简单的 Mac EPUB 阅读器。下载上面的 ZIP，解压后把 **书页.app** 拖进“应用程序”。打开 EPUB 即可阅读，支持拖入文件、目录跳转、字号调整、日夜主题和阅读位置保存。

支持中、英、日、西班牙语界面，在右上角的阅读设置中切换。书籍正文保留原文。所有阅读操作都在本地完成。

## Privacy

Books are extracted to a temporary local folder. File paths, reading positions, appearance, and language preferences are saved in local macOS preferences. There is no developer backend, analytics, account, or upload. Book scripts are disabled and remote resources are blocked. Extracted data is removed on normal close; a crash may leave temporary files for macOS to clean up.

## Build from source

Install Apple's Command Line Tools (`xcode-select --install`). Swift 6+ and macOS 14+ are required; Python 3 is used only for tests. No package installation is needed.

```sh
./test.sh
./build.sh
open build/书页.app
./package.sh
```

The build creates a universal application with both `arm64` and `x86_64` executables. `package.sh` creates a ready-to-use ZIP and SHA-256 checksums in `dist/`. To test your own book:

```sh
./test.sh /path/to/your-book.epub
```

The fixture suite checks EPUB3 navigation, nesting, anchor links, Unicode and escaped filenames, missing-TOC fallback, spine selection, translation coverage, corrupted ZIP data, path traversal, symlinks, encryption, and truncated archives. Real books are never included in this repository or release.

See [AGENTS.md](AGENTS.md) for the code map and contribution rules, [DESIGN.md](DESIGN.md) for visual choices, and [RELEASING.md](RELEASING.md) for publishing.

## License

[MIT](LICENSE). Built with Apple's system frameworks and system zlib. Design guidance: [Taste](https://github.com/Hmbown/taste) and [Impeccable](https://github.com/pbakaus/impeccable).

## Say hello

Built by [Michael Lu](https://x.com/michael_lu_03).

## More products

- [OwnWords](https://github.com/Michaellzd/ownwords) — your own thoughts, expressed clearly.
- [AI Takeaway](https://aitakeaway.net/)
- [Auralume AI](https://auralumeai.com/)
- [Encorette](https://burningbridgesmv.org/)
