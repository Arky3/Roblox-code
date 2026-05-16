import { useState, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import AssignmentCard from '../components/AssignmentCard'
import WorkloadMeter from '../components/WorkloadMeter'
import CalendarView from '../components/CalendarView'
import { getDaysUntilDue } from '../utils/scheduling'

export default function Dashboard({ assignments, onToggleComplete, onDeleteAssignment, settings }) {
  const navigate = useNavigate()
  const [filter, setFilter] = useState('upcoming') // upcoming | all | completed

  const name = settings?.studentName

  const sorted = useMemo(() => {
    const active = assignments.filter((a) => !a.completed)
    const done = assignments.filter((a) => a.completed)

    // Sort active: overdue first, then by due date
    active.sort((a, b) => {
      const dA = getDaysUntilDue(a.dueDate)
      const dB = getDaysUntilDue(b.dueDate)
      return dA - dB
    })

    return { active, done }
  }, [assignments])

  const displayed = useMemo(() => {
    if (filter === 'completed') return sorted.done
    if (filter === 'all') return [...sorted.active, ...sorted.done]
    // upcoming = active only
    return sorted.active
  }, [filter, sorted])

  const overdueCt = sorted.active.filter((a) => getDaysUntilDue(a.dueDate) < 0).length

  return (
    <div className="min-h-screen bg-[#0a0a0f] pt-20">
      <div className="max-w-7xl mx-auto px-4 py-6">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-[#f0f0f5]">
            {name ? `Hey ${name} 👋` : 'Your assignments'}
          </h1>
          {overdueCt > 0 && (
            <p className="text-[#f75555] text-sm mt-1">
              ⚠️ {overdueCt} overdue — take care of {overdueCt === 1 ? 'it' : 'them'} first
            </p>
          )}
        </div>

        <div className="flex flex-col md:flex-row gap-6">
          {/* Left panel */}
          <div className="w-full md:w-[40%] flex-shrink-0">
            <WorkloadMeter assignments={assignments} />

            <div className="flex gap-1 mb-4 bg-[#13131a] p-1 rounded-xl border border-[#1e1e2e]">
              {[
                { key: 'upcoming', label: 'Upcoming' },
                { key: 'all', label: 'All' },
                { key: 'completed', label: 'Done' },
              ].map(({ key, label }) => (
                <button
                  key={key}
                  onClick={() => setFilter(key)}
                  className={`flex-1 py-1.5 rounded-lg text-xs font-medium transition-all ${
                    filter === key
                      ? 'bg-[#0a0a0f] text-[#f0f0f5] shadow'
                      : 'text-[#6b6b80] hover:text-[#f0f0f5]'
                  }`}
                >
                  {label}
                  {key === 'upcoming' && sorted.active.length > 0 && (
                    <span className="ml-1 text-[10px] text-[#6b6b80]">({sorted.active.length})</span>
                  )}
                </button>
              ))}
            </div>

            {displayed.length === 0 ? (
              <EmptyState filter={filter} onScan={() => navigate('/')} />
            ) : (
              <div className="space-y-2 max-h-[calc(100vh-280px)] overflow-y-auto pr-1 scrollbar-thin">
                {displayed.map((a) => (
                  <AssignmentCard
                    key={a.id}
                    assignment={a}
                    onToggleComplete={onToggleComplete}
                    onDelete={onDeleteAssignment}
                  />
                ))}
              </div>
            )}
          </div>

          {/* Right panel */}
          <div className="flex-1 min-w-0">
            <CalendarView assignments={assignments} onToggleComplete={onToggleComplete} />
          </div>
        </div>
      </div>
    </div>
  )
}

function EmptyState({ filter, onScan }) {
  const messages = {
    upcoming: {
      icon: '🎉',
      title: "You're all caught up!",
      body: 'No upcoming assignments. Scan something to get started.',
      action: true,
    },
    completed: {
      icon: '✅',
      title: 'No completed assignments yet',
      body: 'Finish some work and check items off your list.',
      action: false,
    },
    all: {
      icon: '📚',
      title: 'No assignments yet',
      body: 'Scan something to get started.',
      action: true,
    },
  }
  const m = messages[filter] || messages.all

  return (
    <div className="text-center py-12 px-4">
      <div className="text-4xl mb-3">{m.icon}</div>
      <p className="text-[#f0f0f5] font-semibold mb-1">{m.title}</p>
      <p className="text-[#6b6b80] text-sm mb-4">{m.body}</p>
      {m.action && (
        <button
          onClick={onScan}
          className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold bg-[#4f8ef7] text-white hover:bg-[#4f8ef7]/90 transition-colors"
        >
          📸 Scan Now
        </button>
      )}
    </div>
  )
}
