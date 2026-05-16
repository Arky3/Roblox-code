import { useCallback, useEffect, useRef } from 'react'

export const useNotifications = (assignments, settings) => {
  const scheduledRef = useRef(new Set())

  const requestPermission = useCallback(async () => {
    if (!('Notification' in window)) return false
    if (Notification.permission === 'granted') return true
    if (Notification.permission === 'denied') return false
    const result = await Notification.requestPermission()
    return result === 'granted'
  }, [])

  const scheduleNotification = useCallback((title, body, fireAt) => {
    const key = `${title}-${fireAt}`
    if (scheduledRef.current.has(key)) return
    const delay = fireAt - Date.now()
    if (delay <= 0) return
    scheduledRef.current.add(key)
    setTimeout(() => {
      if (Notification.permission === 'granted') {
        new Notification(title, { body, icon: '/favicon.ico' })
      }
    }, delay)
  }, [])

  useEffect(() => {
    if (Notification.permission !== 'granted') return
    if (!settings?.notifications) return

    assignments.forEach((a) => {
      if (a.completed) return
      const due = new Date(a.dueDate + 'T09:00:00')

      if (settings.notifications.dayOf) {
        scheduleNotification(
          `📚 Due today: ${a.name}`,
          `${a.subject} assignment is due today!`,
          due.getTime()
        )
      }

      if (settings.notifications.dueSoon) {
        const dayBefore = new Date(due)
        dayBefore.setDate(dayBefore.getDate() - 1)
        scheduleNotification(
          `⚠️ Due tomorrow: ${a.name}`,
          `${a.subject} is due tomorrow. Don't forget!`,
          dayBefore.getTime()
        )
      }

      if (settings.notifications.startReminder && a.startByDate) {
        const startAt = new Date(a.startByDate + 'T09:00:00')
        scheduleNotification(
          `⚡ Time to start: ${a.name}`,
          `Start working on your ${a.subject} assignment — it's due ${a.dueDate}`,
          startAt.getTime()
        )
      }
    })
  }, [assignments, settings, scheduleNotification])

  return { requestPermission }
}
