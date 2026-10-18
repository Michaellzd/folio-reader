from pathlib import Path
import sys, zipfile

root = Path(sys.argv[1])
root.mkdir(parents=True, exist_ok=True)
files = {
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml': '<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OPS/book.opf"/></rootfiles></container>',
    'OPS/book.opf': '''<package xmlns="http://www.idpf.org/2007/opf" version="3.0"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>测试书 &amp; 阅读</dc:title><dc:creator>作者</dc:creator></metadata><manifest><item id="one" href="第一%20章.xhtml" media-type="application/xhtml+xml"/><item id="two" href="second.xhtml" media-type="application/xhtml+xml"/><item id="extra" href="extra.xhtml" media-type="application/xhtml+xml"/><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="cover" href="cover.svg" media-type="image/svg+xml" properties="cover-image"/></manifest><spine><itemref idref="one"/><itemref idref="extra" linear="no"/><itemref idref="two"/></spine></package>''',
    'OPS/nav.xhtml': '''<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><body><nav epub:type="toc"><ol><li><a href="第一%20章.xhtml">第一章</a><ol><li><a href="第一%20章.xhtml#section2">小节</a></li></ol></li><li><a href="second.xhtml">第二章</a></li></ol></nav></body></html>''',
    'OPS/第一 章.xhtml': '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>第一章</title></head><body><h1>第一章</h1><p>打开一本书。</p><h2 id="section2">小节</h2></body></html>',
    'OPS/second.xhtml': '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>第二章</title></head><body><h1>第二章</h1><p>继续阅读。</p></body></html>',
    'OPS/extra.xhtml': '<html><body>extra</body></html>',
    'OPS/cover.svg': '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="140"><rect width="100" height="140" fill="olive"/></svg>',
}
def write(name, contents):
    with zipfile.ZipFile(root / name, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path, content in contents.items():
            archive.writestr(path, content)
write('中文 空格.epub', files)
write('fallback.epub', {k: v for k, v in files.items() if k != 'OPS/nav.xhtml'})
write('traversal.epub', {**files, '../escape': 'bad'})
write('drm.epub', {**files, 'META-INF/encryption.xml': '<encryption><EncryptedData><EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/></EncryptedData></encryption>'})
with zipfile.ZipFile(root / 'symlink.epub', 'w') as archive:
    item = zipfile.ZipInfo('link'); item.create_system = 3; item.external_attr = 0o120777 << 16
    archive.writestr(item, '/tmp')
with zipfile.ZipFile(root / 'empty.epub', 'w'):
    pass
original = (root / '中文 空格.epub').read_bytes()
(root / 'truncated.epub').write_bytes(original[:60])
bad = bytearray(original)
index = bad.index(b'PK\x01\x02')
bad[index + 16] ^= 0xFF
(root / 'corrupt.epub').write_bytes(bad)
