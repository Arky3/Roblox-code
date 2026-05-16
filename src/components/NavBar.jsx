import { Link, useLocation } from 'react-router-dom'
import { useState } from 'react'

export default function NavBar({ onSettingsOpen, notifEnabled, onNotifToggle }) {
  const location = useLocation()

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-6 py-4 border-b border-[#1e1e2e] bg-[#0a0a0f]/90 backdrop-blur-sm">
      <Link to="/" className="flex items-center gap-2 text-[#f0f0f5] font-semibold text-lg hover:text-[#4f8ef7] transition-colors">
        <span className="text-xl">📸</span>
        <span>SnapStudy</span>
      </Link>

      <div className="flex items-center gap-4">
        <Link
          to="/dashboard"
          className={`text-sm font-medium transition-colors ${
            location.pathname === '/dashboard'
              ? 'text-[#4f8ef7]'
              : 'text-[#6b6b80] hover:text-[#f0f0f5]'
          }`}
        >
          Dashboard
        </Link>

        <button
          onClick={onNotifToggle}
          title={notifEnabled ? 'Notifications on' : 'Notifications off'}
          className={`p-2 rounded-lg transition-colors ${
            notifEnabled
              ? 'text-[#22d3a5] bg-[#22d3a5]/10 hover:bg-[#22d3a5]/20'
              : 'text-[#6b6b80] hover:text-[#f0f0f5] hover:bg-[#1e1e2e]'
          }`}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
            <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
          </svg>
        </button>

        <button
          onClick={onSettingsOpen}
          className="p-2 rounded-lg text-[#6b6b80] hover:text-[#f0f0f5] hover:bg-[#1e1e2e] transition-colors"
          title="Settings"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="3"/>
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
          </svg>
        </button>
      </div>
    </nav>
  )
}
