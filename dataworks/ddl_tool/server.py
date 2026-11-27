"""业务库 DDL 补齐工具：本地启动一个小服务，浏览器里录入，每次修改直接写进一个 .sql 文件。

    python3 dataworks/ddl_tool/server.py                 # 默认文件 dataworks/input/src_ddl.sql，端口 8765
    python3 dataworks/ddl_tool/server.py --file D:/x.sql --port 9000 --no-browser

启动时文件不存在就自动创建；页面上每次保存 / 删除都会整份重写该文件（先写临时文件再替换，上一版留在 .bak）。
只用 Python 标准库，可以把 ddl_tool 目录单独拷到别的电脑运行（表清单在同目录 src_tables.json）。
文件格式与 dataworks/standard/src_ddl.py 一致：每张表前为标记行 -- @table 数据源:表名、@at 录入时间、@status 弃用、@reason、@note，其后为 CREATE TABLE 语句（弃用表可以没有）。
"""
import argparse, datetime, http.server, json, os, pathlib, re, shutil, socketserver, threading, webbrowser

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_FILE = HERE.parent / 'input' / 'src_ddl.sql'
LOCK = threading.Lock()
STATE = {'file': None, 'entries': {}}


def now():
    return datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')


META = ('at', 'status', 'reason', 'note')   # 每张表的标记行：-- @at / @status / @reason / @note


def read_file(path):
    """→ {key: {'ddl', 'at', 'status', 'reason', 'note'}}"""
    if not path.exists():
        return {}
    text = path.read_text(encoding='utf-8-sig')
    parts = re.split(r'^--\s*@table\s+(\S+)\s*$', text, flags=re.M)
    out = {}
    for k in range(1, len(parts), 2):
        body, e = parts[k + 1], {}
        for key in META:
            m = re.search(rf'^--\s*@{key}\s+(.*)$', body, re.M)
            if m and m.group(1).strip():
                e[key] = m.group(1).strip()
        ddl = re.sub(r'^--\s*@(' + '|'.join(META) + r')\b.*$\n?', '', body, flags=re.M).strip()
        if ddl:
            e['ddl'] = ddl
        if e.get('ddl') or e.get('status'):
            out[parts[k]] = e
    return out


def write_file(path, entries):
    keys = sorted(entries)
    ddl_n = sum(1 for k in keys if entries[k].get('ddl') and not k.startswith('?:'))
    dep_n = sum(1 for k in keys if entries[k].get('status') == '弃用')
    head = ['-- 业务库表 DDL（dataworks/ddl_tool 业务库 DDL 补齐工具维护，请勿手工改动 -- @ 开头的标记行）',
            f'-- 更新时间：{now()}',
            f'-- 共 {len(keys)} 张：已录入 DDL {ddl_n} 张，标记弃用 {dep_n} 张，未对上业务库表 {sum(1 for k in keys if k.startswith("?:"))} 张',
            '-- 格式：每张表前为标记行 -- @table 数据源:表名 / @at 录入时间 / @status 弃用 / @reason 原因 / @note 备注，其后为原始 CREATE TABLE 语句（弃用表可以没有）', '']
    blocks = []
    for k in keys:
        e = entries[k]
        lines = [f'-- @table {k}'] + [f'-- @{m} {str(e[m]).replace(chr(10), " ").strip()}' for m in META if e.get(m)]
        if e.get('ddl'):
            lines.append(e['ddl'].strip())
        blocks.append('\n'.join(lines) + '\n')
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + '.tmp')
    tmp.write_text('\n'.join(head) + '\n' + '\n'.join(blocks), encoding='utf-8')
    if path.exists():
        shutil.copyfile(path, path.with_suffix(path.suffix + '.bak'))
    os.replace(tmp, path)


class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(HERE), **k)

    def log_message(self, *a):
        pass

    def _json(self, obj, code=200):
        b = json.dumps(obj, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(b)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path.startswith('/api/state'):
            tables = json.loads((HERE / 'src_tables.json').read_text(encoding='utf-8')) if (HERE / 'src_tables.json').exists() else {'tables': []}
            with LOCK:
                return self._json({'file': str(STATE['file']), 'entries': STATE['entries'], **tables})
        if self.path in ('/', ''):
            self.path = '/index.html'
        return super().do_GET()

    def do_POST(self):
        if not self.path.startswith('/api/entries'):
            return self._json({'error': 'not found'}, 404)
        try:
            req = json.loads(self.rfile.read(int(self.headers.get('Content-Length') or 0)).decode('utf-8'))
        except (ValueError, UnicodeDecodeError):
            return self._json({'error': '请求格式不对'}, 400)
        with LOCK:
            E = STATE['entries']
            for k, v in (req.get('set') or {}).items():      # 整条替换：没有 DDL 也没有状态的视为删除
                if not isinstance(v, dict):
                    continue
                e = {m: str(v[m]).strip() for m in ('ddl', *META) if str(v.get(m) or '').strip()}
                if e.get('ddl') or e.get('status'):
                    e.setdefault('at', now())
                    E[k] = e
                else:
                    E.pop(k, None)
            for k in req.get('del') or []:
                E.pop(k, None)
            try:
                write_file(STATE['file'], E)
            except OSError as e:
                return self._json({'error': f'写文件失败：{e}'}, 500)
            return self._json({'ok': True, 'count': len(E), 'saved_at': now(), 'entries': E})


def main():
    ap = argparse.ArgumentParser(description='业务库 DDL 补齐工具')
    ap.add_argument('--file', default=str(DEFAULT_FILE), help='DDL 文件路径（不存在会自动创建）')
    ap.add_argument('--port', type=int, default=8765)
    ap.add_argument('--no-browser', action='store_true')
    a = ap.parse_args()
    f = pathlib.Path(a.file).expanduser().resolve()
    STATE['file'] = f
    STATE['entries'] = read_file(f)
    if not f.exists():
        write_file(f, {})
        print(f'已创建 DDL 文件：{f}')
    else:
        print(f'使用已有 DDL 文件：{f}（已录入 {len(STATE["entries"])} 张）')
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(('127.0.0.1', a.port), H) as srv:
        url = f'http://127.0.0.1:{a.port}/'
        print(f'已启动：{url}  （关闭窗口或 Ctrl+C 退出；录入内容实时写入上面的文件）')
        if not a.no_browser:
            threading.Timer(0.6, lambda: webbrowser.open(url)).start()
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == '__main__':
    main()
