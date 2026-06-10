<div align="center">

# 🐱 Nyantivirus

### the cutest antivirus in the world `(=^･ω･^=)`

A kawaii control panel for **Microsoft Defender** + **ClamAV** on Windows.
Free, open source, no telemetry, ridiculously cute.

</div>

---

## ✨ What is this?

Nyantivirus is a single-file PowerShell + WinForms app that gives you a friendly,
pastel, animated front-end to the security tools already on your Windows PC.
It doesn't replace your antivirus — it **drives** the powerful ones (Microsoft
Defender and ClamAV) through a UI a cat would approve of.

## 🛡️ Features

- **Defender control** — quick / full / folder scans, definition updates, live status
- **Background scans** — scans run in the background; the kitty tells you when it's done (+ sound)
- **Soft hardening** — one click to raise cloud protection, PUA, MAPS to recommended levels
- **ClamAV second opinion** — setup, virus-db update (freshclam) and on-demand folder scans
- **Threats viewer** — list & remove Defender detections, drop an **EICAR test** to prove protection works
- **Scan history** — every scan is logged to `scan-history.log`
- **Maximum kawaii** — falling petals during scans, a dancing cat mascot, confetti when you're clean,
  floating hearts, a sparkly UI, and a little "nya" melody on launch 🎵

## 📦 Requirements

- Windows 10 / 11
- Windows PowerShell 5.1 (built in)
- Admin rights (the app auto-elevates via UAC — Defender settings require it)
- *(optional)* [ClamAV](https://www.clamav.net/) installed at `C:\Program Files\ClamAV` for the second-opinion scanner

## 🚀 Install

```powershell
git clone https://github.com/<you>/nyantivirus.git
cd nyantivirus
# optional: create a desktop shortcut with the cat icon
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Then just **double-click `Nyantivirus.bat`** (or the desktop shortcut) and accept the UAC prompt.

> First run: click **Harden (Soft)**, then **ClamAV: Setup + Update** (downloads ~150 MB of virus db).

## 🗂️ Project layout

```
Nyantivirus.ps1     the app (UI + logic)
Nyantivirus.bat     launcher (bypasses ExecutionPolicy, hidden console)
nyantivirus.ico     cat icon
install.ps1         creates a desktop shortcut
assets/             bundled font (Sniglet) + Twemoji color emojis + mascots
```

## 🙏 Credits

See [ATTRIBUTION.md](ATTRIBUTION.md). Built with Twemoji, Sniglet and Noto Emoji — all open licenses.

## ⚖️ License

Code released under the [MIT License](LICENSE). Bundled assets keep their own licenses (see ATTRIBUTION).

<div align="center">

made with ♥ — `(づ｡◕‿‿◕｡)づ`

</div>
