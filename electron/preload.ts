import { contextBridge, ipcRenderer } from 'electron'

contextBridge.exposeInMainWorld('electronAPI', {
  getHistory: () => ipcRenderer.invoke('get-history'),
  onHistoryUpdated: (callback: (history: any[]) => void) => {
    ipcRenderer.on('history-updated', (_event, history) => callback(history))
  },
  copyItem: (content: string, type: 'text' | 'image') => ipcRenderer.send('copy-item', content, type),
  clearHistory: () => ipcRenderer.send('clear-history'),
  togglePin: (id: string) => ipcRenderer.invoke('toggle-pin', id),
  deleteItem: (id: string) => ipcRenderer.invoke('delete-item', id),
  getLaunchSettings: () => ipcRenderer.invoke('get-launch-settings'),
  setLaunchAtLogin: (openAtLogin: boolean) => ipcRenderer.invoke('set-launch-at-login', openAtLogin),
  checkAccessibility: () => ipcRenderer.invoke('check-accessibility'),
  openAccessibilitySettings: () => ipcRenderer.send('open-accessibility-settings'),
  getAllSettings: () => ipcRenderer.invoke('get-all-settings'),
  updateSetting: (key: string, value: string) => ipcRenderer.invoke('update-setting', key, value),
  openExternal: (url: string) => ipcRenderer.send('open-external', url),
})
