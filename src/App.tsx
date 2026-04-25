import { useState, useEffect } from 'react'
import { Search, Pin, Trash2, X, Settings, ArrowLeft, ShieldCheck, Power, AlertCircle, RefreshCcw, Clipboard, Image as ImageIcon, Clock, Hash, Calendar, Volume2, Type, LogOut } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

interface ClipboardItem {
  id: string
  type: 'text' | 'image'
  content: string
  timestamp: number
  is_pinned: boolean
}

// Global interface for Electron API (defined in preload.ts)
declare global {
  interface Window {
    electronAPI: {
      getHistory: () => Promise<ClipboardItem[]>
      onHistoryUpdated: (callback: (history: ClipboardItem[]) => void) => void
      copyItem: (content: string, type: 'text' | 'image') => void
      clearHistory: () => void
      togglePin: (id: string) => Promise<ClipboardItem[]>
      deleteItem: (id: string) => Promise<ClipboardItem[]>
      getLaunchSettings: () => Promise<boolean>
      setLaunchAtLogin: (enabled: boolean) => Promise<boolean>
      checkAccessibility: () => Promise<boolean>
      openAccessibilitySettings: () => void
      getAllSettings: () => Promise<any>
      updateSetting: (key: string, value: string) => Promise<boolean>
      openExternal: (url: string) => void
      quitApp: () => void
    }
  }
}

function App() {
  const [history, setHistory] = useState<ClipboardItem[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [view, setView] = useState<'home' | 'settings'>('home')
  const [isLaunchAtLogin, setIsLaunchAtLogin] = useState(false)
  const [isAccessible, setIsAccessible] = useState(false)
  const [isCheckingUpdate, setIsCheckingUpdate] = useState(false)
  const [updateStatus, setUpdateStatus] = useState<string | null>(null)
  const [settings, setSettings] = useState({
    historyLimit: '100',
    autoCleanupDays: '7',
    pasteAsPlainText: 'false',
    soundEnabled: 'true'
  })

  useEffect(() => {
    // Initial fetch
    window.electronAPI.getHistory().then(setHistory)
    
    // Check settings
    window.electronAPI.getLaunchSettings().then(setIsLaunchAtLogin)
    window.electronAPI.checkAccessibility().then(setIsAccessible)
    window.electronAPI.getAllSettings().then(setSettings)

    // Listen for updates
    window.electronAPI.onHistoryUpdated((newHistory) => {
      setHistory(newHistory)
    })
  }, [])

  const filteredHistory = history.filter(item => {
    if (item.type === 'text') {
      return item.content.toLowerCase().includes(searchQuery.toLowerCase())
    }
    return true
  })

  const formatTime = (timestamp: number) => {
    const date = new Date(timestamp)
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  }

  return (
    <div className="app-container">
      <header className="header">
        {view === 'home' ? (
          <>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <img 
                src="./pure-clip.png" 
                alt="PureClip" 
                style={{ width: '24px', height: '24px' }} 
              />
              <h2 style={{ fontSize: '20px', margin: 0, fontWeight: 700, letterSpacing: '-0.5px' }}>PureClip</h2>
            </div>
            <div style={{ display: 'flex', gap: '12px' }}>
              <button 
                onClick={() => {
                  if (window.confirm('Sabitlenmemiş tüm geçmişi temizlemek istediğinize emin misiniz?')) {
                    window.electronAPI.clearHistory()
                  }
                }}
                className="header-icon-button"
                title="Tümünü Temizle"
              >
                <Trash2 size={16} />
              </button>
              <button 
                onClick={() => setView('settings')}
                className="header-icon-button"
                title="Ayarlar"
              >
                <Settings size={16} />
              </button>
            </div>
          </>
        ) : (
          <>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <button 
                onClick={() => setView('home')}
                className="header-icon-button"
              >
                <ArrowLeft size={16} />
              </button>
              <h2 style={{ fontSize: '16px', margin: 0, fontWeight: 600 }}>Ayarlar</h2>
            </div>
          </>
        )}
      </header>

      <main className="main-content">
        {view === 'home' ? (
          <>
            <div className="search-container">
              <div className="search-wrapper">
                <Search className="search-icon" size={16} />
                <input 
                  type="text" 
                  placeholder="Geçmişte ara..." 
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  autoFocus
                />
                {searchQuery && (
                  <button className="clear-search" onClick={() => setSearchQuery('')}>
                    <X size={14} />
                  </button>
                )}
              </div>
            </div>

            <div className="history-list">
              <AnimatePresence mode="popLayout">
                {filteredHistory.map((item) => (
                  <motion.div
                    key={item.id}
                    layout
                    initial={{ opacity: 0, y: 10, scale: 0.95 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.9, transition: { duration: 0.2 } }}
                    whileHover={{ 
                      scale: 1.02,
                      backgroundColor: 'rgba(255, 255, 255, 0.15)',
                      transition: { duration: 0.2 }
                    }}
                    className={`item-card ${item.is_pinned ? 'pinned' : ''}`}
                    onClick={() => window.electronAPI.copyItem(item.content, item.type)}
                  >
                    <div className="card-actions">
                      <button 
                        className={`action-button ${item.is_pinned ? 'pin-active' : ''}`}
                        onClick={(e) => {
                          e.stopPropagation()
                          window.electronAPI.togglePin(item.id).then(setHistory)
                        }}
                        title={item.is_pinned ? "Sabitlemeyi Kaldır" : "Sabitle"}
                      >
                        <Pin size={14} style={{ transform: item.is_pinned ? 'none' : 'rotate(-45deg)' }} />
                      </button>

                      <button 
                        className="action-button delete-hover"
                        onClick={(e) => {
                          e.stopPropagation()
                          if (window.confirm('Bu öğeyi silmek istediğinize emin misiniz?')) {
                            window.electronAPI.deleteItem(item.id).then(setHistory)
                          }
                        }}
                        title="Sil"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>

                    {item.type === 'text' ? (
                      <div className="item-text">{item.content}</div>
                    ) : (
                      <img src={item.content} alt="clipboard" className="item-image" />
                    )}
                    
                    <div className="item-footer">
                      <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                        {item.type === 'text' ? <Clock size={10} /> : <ImageIcon size={10} />}
                        <span>{formatTime(item.timestamp)}</span>
                      </div>
                      {item.is_pinned && <span className="pin-badge">Sabitlendi</span>}
                    </div>
                  </motion.div>
                ))}
              </AnimatePresence>
              
              {filteredHistory.length === 0 && (
                <div className="empty-state">
                  <Clipboard size={48} strokeWidth={1} style={{ marginBottom: '12px', opacity: 0.3 }} />
                  <p>{searchQuery ? 'Sonuç bulunamadı' : 'Geçmiş henüz boş'}</p>
                </div>
              )}
            </div>
          </>
        ) : (
          <div className="settings-view">
            <div className="settings-section">
              <div className="settings-item">
                <div className="settings-info">
                  <Power size={18} className="settings-icon" />
                  <div>
                    <div className="settings-label">Otomatik Başlat</div>
                    <div className="settings-desc">Bilgisayar açıldığında başlasın</div>
                  </div>
                </div>
                <label className="switch">
                  <input 
                    type="checkbox" 
                    checked={isLaunchAtLogin}
                    onChange={async (e) => {
                      const checked = e.target.checked
                      const result = await window.electronAPI.setLaunchAtLogin(checked)
                      setIsLaunchAtLogin(result)
                    }}
                  />
                  <span className="slider round"></span>
                </label>
              </div>

              <div className="settings-item">
                <div className="settings-info">
                  <Hash size={18} className="settings-icon" />
                  <div>
                    <div className="settings-label">Geçmiş Sınırı</div>
                    <div className="settings-desc">Saklanacak maksimum öğe sayısı</div>
                  </div>
                </div>
                <select 
                  value={settings.historyLimit}
                  onChange={(e) => {
                    const val = e.target.value
                    window.electronAPI.updateSetting('historyLimit', val)
                    setSettings(prev => ({ ...prev, historyLimit: val }))
                  }}
                  className="settings-select"
                >
                  <option value="10">10 Öğe</option>
                  <option value="20">20 Öğe</option>
                  <option value="50">50 Öğe</option>
                  <option value="100">100 Öğe</option>
                </select>
              </div>

              <div className="settings-item">
                <div className="settings-info">
                  <Calendar size={18} className="settings-icon" />
                  <div>
                    <div className="settings-label">Otomatik Temizleme</div>
                    <div className="settings-desc">Şu süreden eski öğeleri sil</div>
                  </div>
                </div>
                <select 
                  value={settings.autoCleanupDays}
                  onChange={(e) => {
                    const val = e.target.value
                    window.electronAPI.updateSetting('autoCleanupDays', val)
                    setSettings(prev => ({ ...prev, autoCleanupDays: val }))
                  }}
                  className="settings-select"
                >
                  <option value="1">1 Gün</option>
                  <option value="3">3 Gün</option>
                  <option value="7">7 Gün</option>
                  <option value="30">30 Gün</option>
                </select>
              </div>
            </div>

            <div className="settings-section">
              <div className="settings-item">
                <div className="settings-info">
                  <Type size={18} className="settings-icon" />
                  <div>
                    <div className="settings-label">Düz Metin Olarak Yapıştır</div>
                    <div className="settings-desc">Biçimlendirmeyi temizler</div>
                  </div>
                </div>
                <label className="switch">
                  <input 
                    type="checkbox" 
                    checked={settings.pasteAsPlainText === 'true'}
                    onChange={(e) => {
                      const val = e.target.checked ? 'true' : 'false'
                      window.electronAPI.updateSetting('pasteAsPlainText', val)
                      setSettings(prev => ({ ...prev, pasteAsPlainText: val }))
                    }}
                  />
                  <span className="slider round"></span>
                </label>
              </div>

              <div className="settings-item">
                <div className="settings-info">
                  <Volume2 size={18} className="settings-icon" />
                  <div>
                    <div className="settings-label">Ses Efektleri</div>
                    <div className="settings-desc">Kopyalandığında hafif ses çal</div>
                  </div>
                </div>
                <label className="switch">
                  <input 
                    type="checkbox" 
                    checked={settings.soundEnabled === 'true'}
                    onChange={(e) => {
                      const val = e.target.checked ? 'true' : 'false'
                      window.electronAPI.updateSetting('soundEnabled', val)
                      setSettings(prev => ({ ...prev, soundEnabled: val }))
                    }}
                  />
                  <span className="slider round"></span>
                </label>
              </div>
            </div>

            <div className="settings-section">
              <div className="settings-item">
                <div className="settings-info">
                  <ShieldCheck size={18} className="settings-icon" />
                  <div>
                    <div className="settings-label">Erişilebilirlik</div>
                    <div className="settings-desc">Otomatik yapıştırma için gereklidir</div>
                  </div>
                </div>
                <div className={`status-badge ${isAccessible ? 'success' : 'warning'}`}>
                  {isAccessible ? 'İzin Verildi' : 'İzin Gerekli'}
                </div>
              </div>

              {!isAccessible && (
              <button 
                className="settings-action-button"
                onClick={() => window.electronAPI.openAccessibilitySettings()}
                style={{ margin: '0 16px 16px', width: 'calc(100% - 32px)' }}
              >
                <AlertCircle size={14} />
                Sistem Ayarlarını Aç
              </button>
            )}
          </div>

          <div className="settings-section">
            <button 
              className="settings-action-button"
              disabled={isCheckingUpdate}
              onClick={async () => {
                setIsCheckingUpdate(true)
                setUpdateStatus('Kontrol ediliyor...')
                
                setTimeout(() => {
                  setIsCheckingUpdate(false)
                  setUpdateStatus('En güncel sürümü kullanıyorsunuz.')
                  setTimeout(() => setUpdateStatus(null), 3000)
                }, 2000)
              }}
              style={{ border: 'none', background: 'transparent' }}
            >
              <RefreshCcw size={14} className={isCheckingUpdate ? 'spin' : ''} />
              {updateStatus || 'Güncelleştirmeleri Denetle'}
            </button>
            <button 
              className="settings-action-button"
              onClick={() => {
                if (window.confirm('Uygulamadan tamamen çıkmak istiyor musunuz?')) {
                  window.electronAPI.quitApp()
                }
              }}
              style={{ border: 'none', background: 'transparent', color: '#ff3b30', borderTop: '0.5px solid var(--border)', borderRadius: 0 }}
            >
              <LogOut size={14} />
              Uygulamadan Tamamen Çık
            </button>
          </div>

            <div className="settings-footer">
              <div style={{ marginBottom: '24px', fontSize: '14px', color: 'var(--accent)', fontWeight: '700', background: 'var(--accent-glow)', padding: '8px 20px', borderRadius: '20px', display: 'inline-block', border: '1px solid var(--accent)' }}>
                Kısayol: ⌘ + ⇧ + V
              </div>
              
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px' }}>
                <img 
                  src="./pure-clip.png" 
                  alt="PureClip" 
                  style={{ width: '64px', height: '64px', marginBottom: '4px' }} 
                />
                <h2 style={{ fontSize: '20px', margin: 0, fontWeight: 700, letterSpacing: '-0.4px' }}>PureClip</h2>
                <span style={{ fontSize: '11px', opacity: 0.5, fontWeight: 500 }}>Sürüm 1.0.0</span>
              </div>

              <div style={{ marginTop: '24px' }}>
                <p 
                  onClick={() => window.electronAPI.openExternal('https://www.cengodev.com')}
                  style={{ cursor: 'pointer', color: 'var(--text)', fontWeight: '500', fontSize: '12px' }}
                >
                  Created by <span style={{ textDecoration: 'underline', color: 'var(--accent)' }}>cengodev</span>
                </p>
                <p style={{ opacity: 0.3, marginTop: '4px', fontSize: '10px' }}>Designed for macOS</p>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  )
}

export default App
