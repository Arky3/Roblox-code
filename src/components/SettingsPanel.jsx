import { useState } from 'react'
import { storage } from '../utils/storage'

export default function SettingsPanel({ open, onClose, settings, onUpdate, onClearAll }) {
  const [apiKey, setApiKey] = useState(storage.getApiKey)
  const [confirmClear, setConfirmClear] = useState(false)

  const handleApiKeySave = () => {
    storage.saveApiKey(apiKey.trim())
    alert('API key saved!')
  }

  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex justify-end" onClick={onClose}>
      <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" />
      <div
        className="relative bg-[#13131a] border-l border-[#1e1e2e] w-full max-w-sm h-full overflow-y-auto shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="p-6">
          <div className="flex items-center justify-between mb-8">
            <h2 className="text-[#f0f0f5] font-semibold text-lg">Settings</h2>
            <button onClick={onClose} className="text-[#6b6b80] hover:text-[#f0f0f5] transition-colors">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>
          </div>

          <section className="mb-8">
            <h3 className="text-xs font-semibold text-[#6b6b80] uppercase tracking-widest mb-4">Profile</h3>
            <label className="block">
              <span className="text-xs text-[#6b6b80] mb-1.5 block">Your name</span>
              <input
                type="text"
                value={settings.studentName}
                onChange={(e) => onUpdate({ studentName: e.target.value })}
                placeholder="e.g. Alex"
                className="w-full bg-[#0a0a0f] border border-[#1e1e2e] rounded-xl px-4 py-2.5 text-sm text-[#f0f0f5] placeholder-[#6b6b80] focus:outline-none focus:border-[#4f8ef7] transition-colors"
              />
            </label>
          </section>

          <section className="mb-8">
            <h3 className="text-xs font-semibold text-[#6b6b80] uppercase tracking-widest mb-4">Study Hours</h3>
            <div className="space-y-4">
              <label className="block">
                <span className="text-xs text-[#6b6b80] mb-1.5 block">Weekday hours available</span>
                <div className="flex items-center gap-3">
                  <input
                    type="range"
                    min="0.5"
                    max="8"
                    step="0.5"
                    value={settings.weekdayHours}
                    onChange={(e) => onUpdate({ weekdayHours: parseFloat(e.target.value) })}
                    className="flex-1 accent-[#4f8ef7]"
                  />
                  <span className="text-sm font-semibold text-[#4f8ef7] w-10 text-right">{settings.weekdayHours}h</span>
                </div>
              </label>
              <label className="block">
                <span className="text-xs text-[#6b6b80] mb-1.5 block">Weekend hours available</span>
                <div className="flex items-center gap-3">
                  <input
                    type="range"
                    min="0.5"
                    max="12"
                    step="0.5"
                    value={settings.weekendHours}
                    onChange={(e) => onUpdate({ weekendHours: parseFloat(e.target.value) })}
                    className="flex-1 accent-[#4f8ef7]"
                  />
                  <span className="text-sm font-semibold text-[#4f8ef7] w-10 text-right">{settings.weekendHours}h</span>
                </div>
              </label>
            </div>
          </section>

          <section className="mb-8">
            <h3 className="text-xs font-semibold text-[#6b6b80] uppercase tracking-widest mb-4">Notifications</h3>
            <div className="space-y-3">
              {[
                { key: 'startReminder', label: 'When to start reminder' },
                { key: 'dueSoon', label: '24 hours before due' },
                { key: 'dayOf', label: 'Day of reminder' },
              ].map(({ key, label }) => (
                <div key={key} className="flex items-center justify-between">
                  <span className="text-sm text-[#f0f0f5]">{label}</span>
                  <button
                    onClick={() =>
                      onUpdate({
                        notifications: {
                          ...settings.notifications,
                          [key]: !settings.notifications[key],
                        },
                      })
                    }
                    className={`w-10 h-5 rounded-full transition-all relative ${
                      settings.notifications[key] ? 'bg-[#22d3a5]' : 'bg-[#1e1e2e]'
                    }`}
                  >
                    <span
                      className={`absolute top-0.5 w-4 h-4 rounded-full bg-white transition-all shadow ${
                        settings.notifications[key] ? 'left-5' : 'left-0.5'
                      }`}
                    />
                  </button>
                </div>
              ))}
            </div>
          </section>

          <section className="mb-8">
            <h3 className="text-xs font-semibold text-[#6b6b80] uppercase tracking-widest mb-4">
              🔑 API Key
            </h3>
            <div className="space-y-2">
              <input
                type="password"
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
                placeholder="sk-ant-..."
                className="w-full bg-[#0a0a0f] border border-[#1e1e2e] rounded-xl px-4 py-2.5 text-sm text-[#f0f0f5] placeholder-[#6b6b80] focus:outline-none focus:border-[#4f8ef7] transition-colors font-mono"
              />
              <button
                onClick={handleApiKeySave}
                className="w-full py-2 rounded-xl text-sm font-medium bg-[#4f8ef7]/10 text-[#4f8ef7] hover:bg-[#4f8ef7]/20 border border-[#4f8ef7]/20 transition-colors"
              >
                Save API Key
              </button>
            </div>
          </section>

          <section>
            <h3 className="text-xs font-semibold text-[#6b6b80] uppercase tracking-widest mb-4">Danger Zone</h3>
            {confirmClear ? (
              <div className="p-4 rounded-xl border border-[#f75555]/30 bg-[#f75555]/5">
                <p className="text-sm text-[#f0f0f5] mb-3">This will delete all assignments. Are you sure?</p>
                <div className="flex gap-2">
                  <button
                    onClick={() => { onClearAll(); setConfirmClear(false); onClose() }}
                    className="flex-1 py-2 rounded-lg text-sm font-medium bg-[#f75555] text-white hover:bg-[#f75555]/90 transition-colors"
                  >
                    Yes, clear all
                  </button>
                  <button
                    onClick={() => setConfirmClear(false)}
                    className="flex-1 py-2 rounded-lg text-sm font-medium bg-[#1e1e2e] text-[#6b6b80] hover:text-[#f0f0f5] transition-colors"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            ) : (
              <button
                onClick={() => setConfirmClear(true)}
                className="w-full py-2.5 rounded-xl text-sm font-medium text-[#f75555] bg-[#f75555]/10 hover:bg-[#f75555]/20 border border-[#f75555]/20 transition-colors"
              >
                Clear all assignments
              </button>
            )}
          </section>
        </div>
      </div>
    </div>
  )
}
