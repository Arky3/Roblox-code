import { useEffect, useState } from 'react'

export default function NotificationManager({ onPermissionChange }) {
  const [shown, setShown] = useState(false)

  useEffect(() => {
    if (!('Notification' in window)) return
    if (Notification.permission === 'granted') {
      onPermissionChange(true)
      return
    }
    if (Notification.permission === 'denied') return

    const timer = setTimeout(() => setShown(true), 2000)
    return () => clearTimeout(timer)
  }, [onPermissionChange])

  const handleAllow = async () => {
    const result = await Notification.requestPermission()
    onPermissionChange(result === 'granted')
    setShown(false)
  }

  if (!shown) return null

  return (
    <div className="fixed bottom-6 right-6 z-50 bg-[#13131a] border border-[#1e1e2e] rounded-2xl p-4 shadow-2xl w-80 animate-in slide-in-from-bottom-4">
      <div className="flex gap-3">
        <div className="w-10 h-10 rounded-xl bg-[#4f8ef7]/10 flex items-center justify-center text-xl flex-shrink-0">
          🔔
        </div>
        <div className="flex-1">
          <p className="text-sm font-semibold text-[#f0f0f5] mb-0.5">Enable notifications</p>
          <p className="text-xs text-[#6b6b80] mb-3">
            Get reminders when to start and when assignments are due.
          </p>
          <div className="flex gap-2">
            <button
              onClick={handleAllow}
              className="flex-1 py-1.5 rounded-lg text-xs font-medium bg-[#4f8ef7] text-white hover:bg-[#4f8ef7]/90 transition-colors"
            >
              Allow
            </button>
            <button
              onClick={() => setShown(false)}
              className="flex-1 py-1.5 rounded-lg text-xs font-medium bg-[#1e1e2e] text-[#6b6b80] hover:text-[#f0f0f5] transition-colors"
            >
              Maybe later
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
