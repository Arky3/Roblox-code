import { useState, useCallback } from 'react'
import { storage } from '../utils/storage'
import { DEFAULT_SETTINGS } from '../constants'

export const useSettings = () => {
  const [settings, setSettings] = useState(() => {
    return storage.getSettings() || DEFAULT_SETTINGS
  })

  const updateSettings = useCallback((changes) => {
    const updated = { ...settings, ...changes }
    storage.saveSettings(updated)
    setSettings(updated)
  }, [settings])

  return { settings, updateSettings }
}
