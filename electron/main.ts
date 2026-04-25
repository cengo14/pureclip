import { app, BrowserWindow, Tray, Menu, nativeImage, clipboard, ipcMain, globalShortcut, screen, systemPreferences, shell } from 'electron'
import path from 'node:path'
import fs from 'node:fs'
import { exec } from 'node:child_process'
import Database from 'better-sqlite3'
import { v4 as uuidv4 } from 'uuid'

let lastText = clipboard.readText()
let lastImage = clipboard.readImage().toDataURL()

// The built directory structure
//
// ├─┬─┬ dist
// │ │ └── index.html
// │ │
// │ ├─┬ dist-electron
// │ │ ├── main.js
// │ │ └── preload.js
// │
const DIST = path.join(__dirname, '../dist')
const VITE_PUBLIC = app.isPackaged ? DIST : path.join(DIST, '../public')

process.env.DIST = DIST
process.env.VITE_PUBLIC = VITE_PUBLIC


let win: BrowserWindow | null
let tray: Tray | null

// 📂 Database Setup
const dbPath = path.join(app.getPath('userData'), 'history.db')
const db = new Database(dbPath)

db.exec(`
  CREATE TABLE IF NOT EXISTS history (
    id TEXT PRIMARY KEY,
    type TEXT,
    content TEXT,
    is_pinned INTEGER DEFAULT 0,
    created_at INTEGER
  );
  CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
  );
`)

// Varsayılan ayarları yükle
const defaultSettings = {
  historyLimit: '100',
  autoCleanupDays: '7',
  pasteAsPlainText: 'false',
  soundEnabled: 'true'
}

for (const [key, value] of Object.entries(defaultSettings)) {
  db.prepare('INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)').run(key, value)
}

function getSetting(key: string): string {
  const row = db.prepare('SELECT value FROM settings WHERE key = ?').get(key) as { value: string }
  return row?.value || ''
}

function updateSetting(key: string, value: string) {
  db.prepare('UPDATE settings SET value = ? WHERE key = ?').run(value, key)
}

interface ClipboardItem {
  id: string
  type: 'text' | 'image'
  content: string
  is_pinned: boolean
  timestamp: number
}

function getHistoryFromDB(): ClipboardItem[] {
  const rows = db.prepare('SELECT * FROM history ORDER BY is_pinned DESC, created_at DESC LIMIT 100').all() as any[]
  return rows.map(row => ({
    id: row.id,
    type: row.type,
    content: row.content,
    is_pinned: !!row.is_pinned,
    timestamp: row.created_at
  }))
}


function createWindow() {
  win = new BrowserWindow({
    width: 350,
    height: 500,
    frame: false,
    show: false,
    resizable: false,
    alwaysOnTop: true,
    transparent: true,
    visualEffectState: 'active',
    vibrancy: 'hud', // Çok daha şeffaf ve canlı bir sistem efekti
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
    },
  })

  // Test actively push message to the Electron-Renderer
  win.webContents.on('did-finish-load', () => {
    win?.webContents.send('main-process-message', (new Date).toLocaleString())
  })

  if (process.env.VITE_DEV_SERVER_URL) {
    win.loadURL(process.env.VITE_DEV_SERVER_URL)
  } else {
    win.loadFile(path.join(DIST, 'index.html'))
  }

  // Hide window when it loses focus
  win.on('blur', () => {
    win?.hide()
  })
}

function createTray() {
  tray = new Tray(getTrayIcon())
  tray.setToolTip('PureClip')
  
  tray.on('click', () => {
    toggleWindow()
  })
}

function getTrayIcon() {
  const trayIconPath = path.join(__dirname, '../resources/trayTemplate.png')
  let icon = nativeImage.createFromPath(trayIconPath)

  if (icon.isEmpty()) {
    icon = nativeImage.createFromNamedImage('NSListViewTemplate')
  }

  const resizedIcon = icon.resize({ width: 18, height: 18 })
  resizedIcon.setTemplateImage(true)
  return resizedIcon
}

function publishHistoryUpdate() {
  const history = getHistoryFromDB()
  win?.webContents.send('history-updated', history)
  return history
}

function toggleWindow() {
  if (!win) return
  if (win.isVisible()) {
    win.hide()
  } else {
    positionWindow()
    win.show()
    win.focus()
  }
}

function positionWindow() {
  if (!win || !tray) return
  const windowBounds = win.getBounds()
  const trayBounds = tray.getBounds()

  // Center window horizontally below tray icon
  const x = Math.round(trayBounds.x + (trayBounds.width / 2) - (windowBounds.width / 2))
  const y = Math.round(trayBounds.y + trayBounds.height + 4)

  win.setPosition(x, y, false)
}

// 🕒 Clipboard Polling
function startPolling() {
  setInterval(() => {
    // 📝 Metin Kontrolü
    const currentText = clipboard.readText().trim()
    if (currentText && currentText !== lastText) {
      lastText = currentText
      addItem({
        id: uuidv4(),
        type: 'text',
        content: currentText,
        is_pinned: false,
        timestamp: Date.now()
      })
    }

    // 🖼️ Resim Kontrolü
    const currentImage = clipboard.readImage()
    if (!currentImage.isEmpty()) {
      const currentDataUrl = currentImage.toDataURL()
      // Resim değişmiş mi kontrol et (Hem veri hem de uzunluk kontrolü ile daha garanti)
      if (currentDataUrl !== lastImage) {
        lastImage = currentDataUrl
        addItem({
          id: uuidv4(),
          type: 'image',
          content: currentDataUrl,
          is_pinned: false,
          timestamp: Date.now()
        })
      }
    }
  }, 500)

  // 🧹 Auto-Cleanup (Every hour, delete unpinned items older than 24h)
  setInterval(cleanupOldItems, 60 * 60 * 1000)
  cleanupOldItems() // Run on start

  // 📸 Masaüstü Ekran Görüntüsü Takibi (Cmd+Shift+3/4 ile alınanlar için)
  const desktopPath = app.getPath('desktop')
  fs.watch(desktopPath, (eventType, filename) => {
    if (eventType === 'rename' && filename && (filename.endsWith('.png') || filename.endsWith('.jpg'))) {
      // macOS varsayılan ekran görüntüsü isimlerini kontrol et (Ekran Resmi veya Screenshot)
      if (filename.includes('Ekran Resmi') || filename.includes('Screenshot')) {
        const filePath = path.join(desktopPath, filename)
        
        // Dosyanın yazılmasının bitmesini beklemek için kısa bir gecikme
        setTimeout(() => {
          try {
            if (fs.existsSync(filePath)) {
              const bitmap = fs.readFileSync(filePath)
              const dataUrl = `data:image/png;base64,${bitmap.toString('base64')}`
              
              addItem({
                id: uuidv4(),
                type: 'image',
                content: dataUrl,
                is_pinned: false,
                timestamp: Date.now()
              })

              // 🗑️ Masaüstünü temiz tutmak için dosyayı siliyoruz
              try {
                fs.unlinkSync(filePath)
              } catch (unlinkErr) {
                console.error('Dosya silinemedi:', unlinkErr)
              }
            }
          } catch (err) {
            console.error('Ekran görüntüsü okuma hatası:', err)
          }
        }, 500)
      }
    }
  })
}

function cleanupOldItems() {
  const days = parseInt(getSetting('autoCleanupDays') || '7')
  const timeAgo = Date.now() - (days * 24 * 60 * 60 * 1000)
  db.prepare('DELETE FROM history WHERE is_pinned = 0 AND created_at < ?').run(timeAgo)
  publishHistoryUpdate()
}

function addItem(item: ClipboardItem) {
  const existing = db.prepare('SELECT is_pinned FROM history WHERE content = ?').get(item.content) as { is_pinned: number } | undefined

  if (existing) {
    // Varsa tarihini güncelle (böylece en başa gelir), sabitleme durumunu koru
    db.prepare('UPDATE history SET created_at = ? WHERE content = ?').run(item.timestamp, item.content)
  } else {
    // Yoksa yeni ekle
    db.prepare('INSERT INTO history (id, type, content, is_pinned, created_at) VALUES (?, ?, ?, ?, ?)').run(
      item.id, item.type, item.content, item.is_pinned ? 1 : 0, item.timestamp
    )
  }

  // 🔊 Ses Efekti (Yeni bir şey yakalandığında)
  if (getSetting('soundEnabled') === 'true') {
    exec('afplay /System/Library/Sounds/Tink.aiff')
  }

  // 📏 Geçmiş Sınırını Uygula (Unpinned olanları sil)
  const limit = parseInt(getSetting('historyLimit'))
  const unpinnedCount = db.prepare('SELECT COUNT(*) as count FROM history WHERE is_pinned = 0').get() as { count: number }
  
  if (unpinnedCount.count > limit) {
    const toDelete = unpinnedCount.count - limit
    db.prepare(`
      DELETE FROM history 
      WHERE id IN (
        SELECT id FROM history 
        WHERE is_pinned = 0 
        ORDER BY created_at ASC 
        LIMIT ?
      )
    `).run(toDelete)
  }
  
  publishHistoryUpdate()
}

// 🔌 IPC Handlers
ipcMain.handle('get-history', () => getHistoryFromDB())

ipcMain.on('copy-item', (_event, content, type) => {
  const isPlainText = getSetting('pasteAsPlainText') === 'true'
  const isSoundEnabled = getSetting('soundEnabled') === 'true'

  if (type === 'text') {
    // Eğer düz metin ayarı açıksa formatı temizle
    const textToCopy = isPlainText ? content.trim() : content
    clipboard.writeText(textToCopy)
  } else {
    const img = nativeImage.createFromDataURL(content)
    clipboard.writeImage(img)
  }
  
  // 🔊 Ses Efekti (macOS sistemi sesi)
  const soundSetting = getSetting('soundEnabled')
  if (soundSetting === 'true') {
    exec('afplay /System/Library/Sounds/Tink.aiff')
  }

  win?.hide()

  // 🚀 Auto-Paste for macOS
  if (process.platform === 'darwin') {
    app.hide()
    
    setTimeout(() => {
      exec(`osascript -e 'tell application "System Events" to keystroke "v" using command down'`)
    }, 500)
  }
})

ipcMain.handle('toggle-pin', (_event, id) => {
  db.prepare('UPDATE history SET is_pinned = 1 - is_pinned WHERE id = ?').run(id)
  return publishHistoryUpdate()
})

ipcMain.handle('delete-item', (_event, id) => {
  const itemToDelete = db.prepare('SELECT content FROM history WHERE id = ?').get(id) as { content: string } | undefined
  
  db.prepare('DELETE FROM history WHERE id = ?').run(id)
  
  // Eğer sildiğimiz şey şu an sistem panosunda olan şeyse, 
  // polling mekanizmasının onu tekrar eklemesini engellemek için lastText'i güncel tutalım
  if (itemToDelete && itemToDelete.content === lastText) {
    // lastText zaten bu, bir şey yapmaya gerek yok ama emin olalım
    lastText = itemToDelete.content 
  }

  return publishHistoryUpdate()
})

ipcMain.on('clear-history', () => {
  db.prepare('DELETE FROM history WHERE is_pinned = 0').run()
  publishHistoryUpdate()
})

// ⚙️ Settings Handlers
ipcMain.handle('get-launch-settings', () => {
  return app.getLoginItemSettings().openAtLogin
})

ipcMain.handle('set-launch-at-login', (_event, openAtLogin) => {
  app.setLoginItemSettings({
    openAtLogin: openAtLogin,
    path: app.getPath('exe')
  })
  return app.getLoginItemSettings().openAtLogin
})

ipcMain.handle('check-accessibility', () => {
  if (process.platform !== 'darwin') return true
  // false parametresi dialog çıkarmadan sadece durumu kontrol eder
  return systemPreferences.isTrustedAccessibilityClient(false)
})

ipcMain.on('open-accessibility-settings', () => {
  if (process.platform === 'darwin') {
    exec('open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"')
  }
})

ipcMain.handle('get-all-settings', () => {
  const rows = db.prepare('SELECT * FROM settings').all() as { key: string, value: string }[]
  const settings: any = {}
  rows.forEach(row => {
    settings[row.key] = row.value
  })
  return settings
})

ipcMain.handle('update-setting', (_event, key, value) => {
  updateSetting(key, value)
  return true
})

ipcMain.on('open-external', (_event, url) => {
  shell.openExternal(url)
})

app.whenReady().then(() => {
  createWindow()
  createTray()
  startPolling()

  // Register Global Shortcut
  globalShortcut.register('CommandOrControl+Shift+V', () => {
    toggleWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
    win = null
  }
})

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow()
  }
})
