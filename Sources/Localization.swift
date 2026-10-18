import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans", english = "en", japanese = "ja", spanish = "es"
    var id: String { rawValue }
    var name: String {
        switch self {
        case .chinese: return "简体中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .spanish: return "Español"
        }
    }
    static var initial: AppLanguage {
        if let saved = UserDefaults.standard.string(forKey: "language"), let language = AppLanguage(rawValue: saved) { return language }
        let system = Locale.preferredLanguages.first ?? "en"
        if system.hasPrefix("zh") { return .chinese }
        if system.hasPrefix("ja") { return .japanese }
        if system.hasPrefix("es") { return .spanish }
        return .english
    }
}

enum L10n {
    // Chinese source keys; each row contains English, Japanese, and Spanish.
    static let translations: [String: [String]] = [
        "标注": ["Highlight", "ハイライト", "Resaltar"],
        "标注颜色": ["Highlight color", "ハイライトの色", "Color del resaltado"],
        "黄色": ["Yellow", "黄色", "Amarillo"],
        "绿色": ["Green", "緑", "Verde"],
        "蓝色": ["Blue", "青", "Azul"],
        "粉色": ["Pink", "ピンク", "Rosa"],
        "进度已自动保存": ["Progress saved automatically", "読書位置を自動保存しました", "Progreso guardado automáticamente"],
        "进度自动保存在本机，下次启动继续阅读。": ["Your position is saved on this Mac. Reading resumes on the next launch.", "読書位置はこのMacに保存され、次回起動時に続きから読めます。", "Tu posición se guarda en este Mac. La lectura se reanuda al abrir la app."],
        "保存书签": ["Save bookmark", "しおりを保存", "Guardar marcador"],
        "已保存": ["Saved", "保存済み", "Guardado"],
        "添加笔记": ["Add note", "メモを追加", "Añadir nota"],
        "书签与笔记": ["Bookmarks & notes", "しおりとメモ", "Marcadores y notas"],
        "还没有书签或笔记": ["No bookmarks or notes yet", "しおりやメモはまだありません", "Aún no hay marcadores ni notas"],
        "点顶部的书签保存位置，或选中文字后添加笔记。": ["Save a place with the bookmark button, or select text and add a note.", "上のしおりボタンで位置を保存するか、本文を選択してメモを追加できます。", "Guarda tu posición con el marcador, o selecciona texto y añade una nota."],
        "书签": ["Bookmark", "しおり", "Marcador"],
        "笔记": ["Note", "メモ", "Nota"],
        "跳到这里": ["Go to this location", "この位置へ移動", "Ir a esta posición"],
        "编辑笔记": ["Edit note", "メモを編集", "Editar nota"],
        "删除": ["Delete", "削除", "Eliminar"],
        "更多操作": ["More actions", "その他の操作", "Más acciones"],
        "删除这条记录？": ["Delete this item?", "この記録を削除しますか？", "¿Eliminar este elemento?"],
        "取消": ["Cancel", "キャンセル", "Cancelar"],
        "保存笔记": ["Save note", "メモを保存", "Guardar nota"],
        "笔记内容": ["Note text", "メモの内容", "Contenido de la nota"],
        "笔记保存在本机，关联到当前阅读位置。": ["Notes stay on this Mac and link back to your reading position.", "メモはこのMacに保存され、読書中の位置に戻れます。", "Las notas se guardan en este Mac y enlazan a tu posición de lectura."],
        "无法保存阅读数据，请重试。": ["Reading data could not be saved. Please try again.", "読書データを保存できませんでした。再度お試しください。", "No se pudieron guardar los datos de lectura. Inténtalo de nuevo."],
        "已保存的数据无法读取，为避免覆盖，请先备份本机阅读数据。": ["Saved data could not be read. Back up this Mac's reading data before repairing it; existing data will not be overwritten.", "保存データを読み込めません。既存のデータは上書きしません。修復する前に読書データをバックアップしてください。", "No se pudieron leer los datos guardados. Haz una copia de seguridad antes de repararlos; no se sobrescribirán los datos existentes."],
        "书页": ["Folio", "Folio", "Folio"],
        "打开 EPUB…": ["Open EPUB…", "EPUBを開く…", "Abrir EPUB…"],
        "打开 EPUB": ["Open EPUB", "EPUBを開く", "Abrir EPUB"],
        "打开": ["Open", "開く", "Abrir"],
        "开始阅读": ["Start reading", "読み始める", "Empezar a leer"],
        "选择一本 EPUB 电子书": ["Choose an EPUB book", "EPUBの本を選択", "Elige un libro EPUB"],
        "阅读": ["Reading", "読書", "Lectura"],
        "上一节": ["Previous section", "前の節", "Sección anterior"],
        "下一节": ["Next section", "次の節", "Sección siguiente"],
        "隐藏目录": ["Hide contents", "目次を隠す", "Ocultar índice"],
        "显示目录": ["Show contents", "目次を表示", "Mostrar índice"],
        "放大字号": ["Increase text size", "文字を大きく", "Aumentar texto"],
        "缩小字号": ["Decrease text size", "文字を小さく", "Reducir texto"],
        "浅色外观": ["Light appearance", "ライト表示", "Aspecto claro"],
        "深色外观": ["Dark appearance", "ダーク表示", "Aspecto oscuro"],
        "目录": ["Contents", "目次", "Índice"],
        "阅读外观": ["Reading appearance", "読書の設定", "Ajustes de lectura"],
        "字号": ["Text size", "文字サイズ", "Tamaño del texto"],
        "纸张": ["Paper", "背景", "Papel"],
        "日间": ["Day", "昼", "Día"],
        "夜间": ["Night", "夜", "Noche"],
        "界面语言": ["Interface language", "表示言語", "Idioma de la interfaz"],
        "翻开一本好书。": ["A little time for a good book.", "一冊の本を、ゆっくりと。", "Un momento para un buen libro."],
        "把 EPUB 拖到这里，留一点时间给阅读。": ["Drop an EPUB here and settle into a story.", "EPUBをここにドロップして、読書の時間を。", "Arrastra un EPUB aquí y disfruta de la lectura."],
        "继续阅读": ["Continue reading", "続きを読む", "Seguir leyendo"],
        "正在打开电子书…": ["Opening your book…", "本を開いています…", "Abriendo el libro…"],
        "松开，开始阅读": ["Drop to start reading", "ドロップして読み始める", "Suelta para empezar a leer"],
        "暂时无法显示": ["Unable to display this section", "この節を表示できません", "No se puede mostrar esta sección"],
        "无法打开这本书": ["Unable to open this book", "この本を開けません", "No se puede abrir este libro"],
        "重新选择…": ["Choose another…", "別の本を選択…", "Elegir otro…"],
        "好": ["OK", "OK", "Aceptar"],
        "第 {current} / {total} 节": ["Section {current} of {total}", "{current} / {total} 節", "Sección {current} de {total}"],
        "请选择 .epub 格式的电子书。": ["Please choose a book in .epub format.", ".epub形式の本を選択してください。", "Elige un libro en formato .epub."],
        "这本书缺少 EPUB 目录信息，请尝试其他 EPUB 文件。": ["This book is missing its EPUB package information. Try another EPUB file.", "EPUBの構成情報がありません。別のEPUBファイルをお試しください。", "Falta la información del paquete EPUB. Prueba con otro archivo."],
        "这本 EPUB 没有可阅读的正文，或使用了不支持的格式。": ["This EPUB has no readable chapters or uses an unsupported format.", "読める本文がないか、未対応の形式です。", "Este EPUB no contiene capítulos legibles o usa un formato no compatible."],
        "这本书带有 DRM 加密。请打开未加密的 EPUB 文件。": ["This book is protected by DRM. Please open a DRM-free EPUB.", "この本はDRMで保護されています。DRMのないEPUBを開いてください。", "Este libro está protegido con DRM. Abre un EPUB sin DRM."],
        "EPUB 章节过大，无法打开。": ["An EPUB chapter is too large to open.", "EPUBの章が大きすぎるため開けません。", "Un capítulo del EPUB es demasiado grande para abrirlo."],
        "EPUB 文件结构不完整或已损坏。": ["The EPUB structure is incomplete or damaged.", "EPUBの構造が不完全か、破損しています。", "La estructura del EPUB está incompleta o dañada."],
        "EPUB 压缩包已损坏、被加密，或超出大小限制。请尝试其他文件。": ["The EPUB archive is damaged, encrypted, or exceeds the size limit. Try another file.", "EPUBが破損・暗号化されているか、サイズ制限を超えています。別のファイルをお試しください。", "El archivo EPUB está dañado, cifrado o supera el límite de tamaño. Prueba con otro archivo."],
        "这一节未能载入，请从目录选择其他章节。": ["This section could not load. Choose another section from the contents.", "この節を読み込めませんでした。目次から別の節を選択してください。", "No se pudo cargar esta sección. Elige otra desde el índice."],
        "无法初始化本地阅读环境，请重新打开应用。": ["The local reader could not initialize. Please reopen the app.", "読書環境を初期化できません。アプリを開き直してください。", "No se pudo iniciar el lector local. Vuelve a abrir la aplicación."]
    ]
    static func text(_ key: String, language: AppLanguage) -> String {
        guard language != .chinese, let row = translations[key] else { return key }
        let index = language == .english ? 0 : language == .japanese ? 1 : 2
        return row[index]
    }
}
