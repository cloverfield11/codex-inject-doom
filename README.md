# ☢️ Codex.inject(DOOM)

[![js-dos v8](https://img.shields.io/badge/Emulator-js--dos_v8-green.svg)](https://js-dos.com)
[![Electron](https://img.shields.io/badge/Target-Electron_App-blue.svg)](https://electronjs.org)

**DOOM injected natively into the Codex IDE runtime.**

A proof-of-concept project demonstrating how to dynamically inject and execute legacy software (DOOM via WebAssembly) natively inside an arbitrary Electron/React application (Codex) using the Chrome DevTools Protocol (CDP) and WebSockets.

<img width="1624" height="1044" alt="Снимок экрана 2026-04-14 в 16 51 25" src="https://github.com/user-attachments/assets/d22c081b-2bab-4001-bc49-51c9b0fdd63d" /> *(Preview placeholder)*

## 🚀 How it works

The magic is entirely fileless and minimally invasive. The project consists of just two files: a bash/python injector and a frontend HTML shell.

1. **CDP Hijacking:** `doom-inject.sh` automatically safely restarts the background Codex process with the `--remote-debugging-port` enabled.
2. **WebSocket Injection:** A native Python script leverages the debugging WebSocket to continuously inject a native CSS-matched interactive tab into Codex's React-based DOM using headless `Runtime.evaluate` evaluation.
3. **Cloud Native Boot:** Once the injected tab is active, the environment is redirected to a lightweight local HTTP server delivering the DOS WebAssembly emulator. 
4. **Zero-weight Assets:** The entire `DOOM.WAD` and emulator core are streamed seamlessly from the cloud (via `dos.zone` CDN) to preserve an incredibly lightweight footprint (< 30KB total). No actual game binaries are stored locally.

## 🛠 Features

- **Painless UI Injection:** Bypasses React's DOM-management to mount a highly cohesive element directly within the Codex sidebar.
- **Deep Clean Emulator:** All JS-DOS visual wrappers, toolbars, virtual keyboards, and settings buttons are stripped away via extreme CSS DOM-piercing to leave a 100% immersive, borderless gaming canvas.
- **Auto-Cleanup Daemon:** Integrates background process handling via `trap`. Closing the terminal (`Ctrl+C`) gracefully spins down the HTTP server, drops the CDP socket, and cleanly shuts down the injected instance.
- **Themed UI:** Features an OS-aware interactive boot screen supporting both `Light` and `Dark` preference modes.

## 🎮 Usage

No Node.js, no `npm install`, and no huge dependencies required. If you have Python 3 and macOS, you're ready to go.

```bash
git clone https://github.com/cloverfield11/doom-codex.git
cd doom-codex

# Launch the automated injection sequence
./doom-inject.sh
```

Watch the terminal report back the successful WebSocket handshake and launch sequence.
Once Codex opens:
1. Click the **`Codex.inject(DOOM);`** tab embedded in the sidebar.
2. Play DOOM.
3. Press **`✕ Return to Codex`** to kill the canvas cleanly and return to your code.

## 👤 Credits & Tools
* Injection logic and UI design by [@cloverfield11](https://github.com/cloverfield11)
* DOOM running in browser using the incredible [js-dos](https://js-dos.com/) v8.
* DOOM assets hosted by indexers at [dos.zone](https://dos.zone/).
