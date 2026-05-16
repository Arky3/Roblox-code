import { Routes, Route } from 'react-router-dom'
import { useState } from 'react'
import NavBar from './components/NavBar'
import SettingsPanel from './components/SettingsPanel'
import NotificationManager from './components/NotificationManager'
import Home from './pages/Home'
import Scan from './pages/Scan'
import Dashboard from './pages/Dashboard'
import { useAssignments } from './hooks/useAssignments'
import { useSettings } from './hooks/useSettings'
import { useNotifications } from './hooks/useNotifications'

export default function App() {
  const { assignments, addAssignments, updateAssignment, deleteAssignment, toggleComplete, clearAll } = useAssignments()
  const { settings, updateSettings } = useSettings()
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [notifEnabled, setNotifEnabled] = useState(
    typeof Notification !== 'undefined' && Notification.permission === 'granted'
  )

  useNotifications(assignments, settings)

  const handleNotifToggle = async () => {
    if (!('Notification' in window)) return
    if (Notification.permission !== 'granted') {
      const result = await Notification.requestPermission()
      setNotifEnabled(result === 'granted')
    } else {
      setNotifEnabled((v) => !v)
    }
  }

  return (
    <>
      <NavBar
        onSettingsOpen={() => setSettingsOpen(true)}
        notifEnabled={notifEnabled}
        onNotifToggle={handleNotifToggle}
      />
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/scan" element={<Scan onAddAssignments={addAssignments} />} />
        <Route
          path="/dashboard"
          element={
            <Dashboard
              assignments={assignments}
              onToggleComplete={toggleComplete}
              onDeleteAssignment={deleteAssignment}
              settings={settings}
            />
          }
        />
      </Routes>
      <SettingsPanel
        open={settingsOpen}
        onClose={() => setSettingsOpen(false)}
        settings={settings}
        onUpdate={updateSettings}
        onClearAll={clearAll}
      />
      <NotificationManager onPermissionChange={setNotifEnabled} />
    </>
  )
}
