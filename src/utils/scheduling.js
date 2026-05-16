export const getDaysUntilDue = (dueDate) => {
  const now = new Date()
  now.setHours(0, 0, 0, 0)
  const due = new Date(dueDate + 'T00:00:00')
  const diff = due - now
  return Math.ceil(diff / (1000 * 60 * 60 * 24))
}

export const getDueLabelAndColor = (dueDate, completed) => {
  if (completed) return { label: 'Completed', color: '#6b6b80', badge: null }
  const days = getDaysUntilDue(dueDate)
  if (days < 0) return { label: `${Math.abs(days)}d overdue`, color: '#f75555', badge: 'OVERDUE' }
  if (days === 0) return { label: 'Due today', color: '#f75555', badge: 'DUE TODAY' }
  if (days === 1) return { label: 'Due tomorrow', color: '#f7a844', badge: 'DUE SOON' }
  if (days <= 3) return { label: `Due in ${days} days`, color: '#f7a844', badge: 'DUE SOON' }
  const due = new Date(dueDate + 'T00:00:00')
  const dayName = due.toLocaleDateString('en-US', { weekday: 'long' })
  return { label: `Due ${dayName}`, color: '#6b6b80', badge: null }
}

export const formatDate = (dateStr) => {
  if (!dateStr) return ''
  const d = new Date(dateStr + 'T00:00:00')
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

export const getStartByLabel = (startByDate) => {
  if (!startByDate) return null
  const days = getDaysUntilDue(startByDate)
  if (days < 0) return '⚡ Should have started already'
  if (days === 0) return '⚡ Start today'
  if (days === 1) return '⚡ Start tomorrow'
  const d = new Date(startByDate + 'T00:00:00')
  const dayName = d.toLocaleDateString('en-US', { weekday: 'long' })
  return `📅 Start by ${dayName}`
}

export const getTotalHoursThisWeek = (assignments) => {
  const now = new Date()
  now.setHours(0, 0, 0, 0)
  const weekEnd = new Date(now)
  weekEnd.setDate(weekEnd.getDate() + 7)

  return assignments
    .filter((a) => {
      if (a.completed) return false
      const due = new Date(a.dueDate + 'T00:00:00')
      return due >= now && due <= weekEnd
    })
    .reduce((sum, a) => sum + (a.estimatedHours || 0), 0)
}

export const getWorkloadColor = (hours) => {
  if (hours <= 4) return '#22d3a5'
  if (hours <= 8) return '#f7a844'
  return '#f75555'
}
