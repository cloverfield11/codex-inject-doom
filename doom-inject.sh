#!/usr/bin/env bash
# ─────────────────────────────────────────────────────
#  doom-inject.sh
#  Инжектирует DOOM в сайдбар Codex через CDP
# ─────────────────────────────────────────────────────

CDP_PORT=9223
HTTP_PORT=1993
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_BIN="/Applications/Codex.app/Contents/MacOS/Codex"

cleanup() {
    echo ""
    echo "  [!] Terminating background processes (Codex, HTTP server)..."
    [ -n "$HTTP_PID" ] && kill -9 $HTTP_PID 2>/dev/null
    local pids=$(lsof -t -i:$HTTP_PORT 2>/dev/null)
    [ -n "$pids" ] && kill -9 $pids 2>/dev/null
    pkill -f "Codex" 2>/dev/null
}
trap cleanup SIGINT SIGTERM EXIT

echo ""
echo "  [1/4] Stopping Codex & freeing port $HTTP_PORT..."
pkill -f "Codex" 2>/dev/null
kill -9 $(lsof -t -i:$HTTP_PORT) 2>/dev/null
sleep 1.2

echo "  [2/4] Starting HTTP server on :$HTTP_PORT..."
cd "$SCRIPT_DIR"
python3 - << 'SERVEREOF' &
from http.server import HTTPServer, SimpleHTTPRequestHandler

BTN = b'''<button onclick="console.log('__DOOM_BACK__')" style="
  position:fixed;top:12px;right:12px;z-index:999999;
  background:rgba(10,10,10,0.85);color:#ddd;
  border:1px solid rgba(255,255,255,0.2);
  padding:8px 18px;cursor:pointer;font-size:13px;
  border-radius:8px;font-family:system-ui,sans-serif;
  backdrop-filter:blur(8px);letter-spacing:.02em;">
  \xe2\x9c\x95 Back to Codex
</button>'''

class H(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path in ('/', '/doom-codex.html'):
            with open('doom-codex.html','rb') as f: body = f.read()
            self.send_response(200)
            self.send_header('Content-Type','text/html')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            super().do_GET()
    def log_message(self, *a): pass

HTTPServer(('',1993), H).serve_forever()
SERVEREOF
HTTP_PID=$!
sleep 0.5

echo "  [3/4] Relaunching Codex with --remote-debugging-port=$CDP_PORT..."
"$CODEX_BIN" --remote-debugging-port=$CDP_PORT >/dev/null 2>&1 &
sleep 3.5

echo "  [4/4] Injecting sidebar & starting event loop..."
echo ""
echo "  ██████╗ ██████╗ ██████╗ ███████╗██╗  ██╗"
echo " ██╔════╝██╔═══██╗██╔══██╗██╔════╝╚██╗██╔╝"
echo " ██║     ██║   ██║██║  ██║█████╗   ╚███╔╝ "
echo " ██║     ██║   ██║██║  ██║██╔══╝   ██╔██╗ "
echo " ╚██████╗╚██████╔╝██████╔╝███████╗██╔╝ ██╗"
echo "  ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝"
echo "     // C O D E X . I N J E C T ( D O O M ) "
echo ""
echo "  Injection created by @cloverfield11 using js-dos"
echo "  Click 'Codex.inject(DOOM);' in sidebar"
echo "  Press '✕ Back to Codex' button inside DOOM to return"
echo "  Ctrl+C to stop"
echo ""

python3 - << 'PYEOF' >/dev/null 2>&1
import urllib.request, json, socket, struct, base64, time

# ── CDP connect ────────────────────────────────────────
try:
    data = urllib.request.urlopen("http://localhost:9223/json", timeout=5).read()
    targets = json.loads(data)
    page = next((t for t in targets if t.get("type") == "page"), None)
    if not page: print("  ✗ No page target"); exit(1)
    ws_url = page["webSocketDebuggerUrl"]
    print(f"  Found target: {page.get('title','?')}")
except Exception as e:
    print(f"  CDP error: {e}"); exit(1)

# ── WebSocket handshake ────────────────────────────────
host, port = "localhost", 9223
path = ws_url.replace(f"ws://localhost:{port}", "")
key = base64.b64encode(b"doomrocks123456789012").decode()
sock = socket.create_connection((host, port), timeout=10)
hs = (f"GET {path} HTTP/1.1\r\nHost: {host}:{port}\r\n"
      f"Upgrade: websocket\r\nConnection: Upgrade\r\n"
      f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n")
sock.send(hs.encode())
if "101" not in sock.recv(1024).decode():
    print("  Handshake failed"); exit(1)

def ws_send(s, text):
    p = text.encode()
    f = bytearray([0x81])
    n = len(p)
    f.append((0x80|n) if n<126 else (0x80|126))
    if n>=126: f.extend(struct.pack(">H",n))
    mask = b'\xde\xad\xbe\xef'
    f.extend(mask)
    f.extend(bytes(b^mask[i%4] for i,b in enumerate(p)))
    s.send(bytes(f))

def ws_recv(s, timeout=5):
    s.settimeout(timeout)
    try:
        hdr = s.recv(2)
        n = hdr[1] & 0x7f
        if n==126: n=struct.unpack(">H",s.recv(2))[0]
        elif n==127: n=struct.unpack(">Q",s.recv(8))[0]
        d=b""
        while len(d)<n: d+=s.recv(n-len(d))
        return d.decode()
    except: return None

# ── Включаем Runtime и Page events ────────────────────
ws_send(sock, json.dumps({"id":1,"method":"Runtime.enable","params":{}}))
time.sleep(0.2); ws_recv(sock, timeout=2)
ws_send(sock, json.dumps({"id":2,"method":"Page.enable","params":{}}))
time.sleep(0.2); ws_recv(sock, timeout=2)

# ── Сохраняем URL Codex ДО перехода ───────────────────
ws_send(sock, json.dumps({"id":5,"method":"Runtime.evaluate",
                          "params":{"expression":"window.location.href","returnByValue":True}}))
codex_url = None
for _ in range(10):
    r = ws_recv(sock, timeout=2)
    if not r: continue
    try:
        msg = json.loads(r)
        if msg.get("id") == 5:
            codex_url = msg.get("result",{}).get("result",{}).get("value")
            print(f"  Codex URL saved: {codex_url}")
            break
    except: pass

DOOM_URL = "http://localhost:1993/doom-codex.html"

# ── JS: сайдбар-кнопка ────────────────────────────────
SIDEBAR_JS = r"""
(() => {
  if (window.__doom_interval) clearInterval(window.__doom_interval);
  function inject() {
    let tab = document.getElementById('doom-injected-tab');
    if (!tab) {
      tab = document.createElement('button');
      tab.id = 'doom-injected-tab';
      tab.className = 'focus-visible:outline-token-border relative px-row-x py-row-y cursor-interaction shrink-0 items-center overflow-hidden rounded-lg text-left text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:cursor-not-allowed disabled:opacity-50 gap-2 flex w-full hover:bg-token-list-hover-background';
      tab.innerHTML = `
        <div class="flex min-w-0 items-center text-base gap-2 flex-1 text-token-foreground">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="opacity:.85;flex-shrink:0">
            <path d="m18 2 4 4"/><path d="m17 7 3-3"/><path d="M19 9 8.7 19.3c-1 1-2.5 1-3.4 0l-.6-.6c-1-1-1-2.5 0-3.4L15 5"/><path d="m9 11 4 4"/><path d="m5 19-3 3"/><path d="m14 4 6 6"/>
          </svg>
          <div class="relative grow overflow-hidden whitespace-nowrap text-sm" style="font-weight:600;color:#e5534b;">
            Codex.inject(DOOM);
          </div>
        </div>`;
      tab.onclick = (e) => {
        e.stopPropagation();
        e.preventDefault();
        console.log('__DOOM_NAVIGATE__');
      };
    }
    const nav = document.querySelector('nav');
    if (nav) {
      const c = nav.querySelector('.px-row-x > .flex-col > .flex-col') || nav;
      if (c && tab.parentElement !== c) {
        tab.removeAttribute('style');
        c.insertBefore(tab, c.firstChild);
      }
    } else {
      if (tab.parentElement !== document.body) {
        Object.assign(tab.style, {position:'fixed',bottom:'60px',left:'8px',zIndex:'99998',width:'220px'});
        document.body.appendChild(tab);
      }
    }
  }
  inject();
  window.__doom_interval = setInterval(inject, 500);
  return 'ok';
})()
"""

def inject_sidebar():
    ws_send(sock, json.dumps({"id":10,"method":"Runtime.evaluate",
                              "params":{"expression":SIDEBAR_JS,"returnByValue":True}}))

inject_sidebar()

# Читаем ответ на инжект
for _ in range(10):
    r = ws_recv(sock, timeout=2)
    if not r: continue
    try:
        msg = json.loads(r)
        if msg.get("id") == 10:
            res = msg.get("result", {})
            if "exceptionDetails" in res:
                print(f"  ✗ Sidebar JS error: {res['exceptionDetails']}")
            else:
                val = res.get("result",{}).get("value","?")
                print(f"  ✓ Sidebar injected: {val}")
            break
    except: pass

print("  Waiting for click... (Ctrl+C to stop)")

on_doom = False

# ── Event loop ─────────────────────────────────────────
while True:
    raw = ws_recv(sock, timeout=60)
    if not raw: continue
    try:
        msg = json.loads(raw)
        method = msg.get("method","")

        if method == "Runtime.consoleAPICalled":
            args = msg.get("params",{}).get("args",[])
            val = args[0].get("value","") if args else ""

            if val == "__DOOM_NAVIGATE__":
                on_doom = True
                print("  ↗ Launching DOOM via Page.navigate...")
                ws_send(sock, json.dumps({"id":20,"method":"Page.navigate",
                                          "params":{"url":DOOM_URL}}))

            elif val == "__DOOM_BACK__" and codex_url:
                print("  ↩ Back to Codex via Page.navigate...")
                ws_send(sock, json.dumps({"id":21,"method":"Page.navigate",
                                          "params":{"url":codex_url}}))

        elif method == "Page.loadEventFired":
            if on_doom:
                on_doom = False
            else:
                # Ждём пока React смонтирует nav, потом инжектируем
                print("  ↩ Codex loaded, waiting for nav...")
                nav_ready = False
                for attempt in range(20):   # до 10 секунд (20 × 0.5s)
                    time.sleep(0.5)
                    ws_send(sock, json.dumps({
                        "id": 30,
                        "method": "Runtime.evaluate",
                        "params": {
                            "expression": "document.querySelector('nav') ? 'yes' : 'no'",
                            "returnByValue": True
                        }
                    }))
                    for _ in range(5):
                        r2 = ws_recv(sock, timeout=1)
                        if not r2: break
                        try:
                            m2 = json.loads(r2)
                            if m2.get("id") == 30:
                                if m2.get("result",{}).get("result",{}).get("value") == 'yes':
                                    nav_ready = True
                                break
                        except: pass
                    if nav_ready:
                        print(f"  ↩ Nav ready after {(attempt+1)*0.5:.1f}s, re-injecting...")
                        break

            inject_sidebar()

    except: pass
PYEOF


wait $HTTP_PID