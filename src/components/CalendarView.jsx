import FullCalendar from '@fullcalendar/react'
import dayGridPlugin from '@fullcalendar/daygrid'
import timeGridPlugin from '@fullcalendar/timegrid'
import interactionPlugin from '@fullcalendar/interaction'
import { useState } from 'react'
import { formatDate } from '../utils/scheduling'

export default function CalendarView({ assignments, onToggleComplete }) {
  const [selectedEvent, setSelectedEvent] = useState(null)

  const events = assignments
    .filter((a) => !a.completed)
    .map((a) => ({
      id: a.id,
      title: a.name,
      date: a.dueDate,
      backgroundColor: a.subjectColor || '#4f8ef7',
      borderColor: 'transparent',
      textColor: '#f0f0f5',
      extendedProps: a,
    }))

  const startByEvents = assignments
    .filter((a) => !a.completed && a.startByDate)
    .map((a) => ({
      id: `start-${a.id}`,
      title: `▶ ${a.name}`,
      date: a.startByDate,
      backgroundColor: (a.subjectColor || '#4f8ef7') + '40',
      borderColor: a.subjectColor || '#4f8ef7',
      textColor: a.subjectColor || '#4f8ef7',
      extendedProps: { ...a, isStartEvent: true },
    }))

  const handleEventClick = ({ event }) => {
    if (event.extendedProps.isStartEvent) return
    setSelectedEvent(event.extendedProps)
  }

  return (
    <div className="relative calendar-wrapper">
      <FullCalendar
        plugins={[dayGridPlugin, timeGridPlugin, interactionPlugin]}
        initialView="dayGridMonth"
        events={[...events, ...startByEvents]}
        eventClick={handleEventClick}
        headerToolbar={{
          left: 'prev,next today',
          center: 'title',
          right: 'dayGridMonth,timeGridWeek',
        }}
        height="auto"
        eventDisplay="block"
        dayMaxEvents={3}
      />

      {selectedEvent && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4" onClick={() => setSelectedEvent(null)}>
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
          <div
            className="relative bg-[#13131a] border border-[#1e1e2e] rounded-2xl p-6 w-full max-w-sm shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => setSelectedEvent(null)}
              className="absolute top-4 right-4 text-[#6b6b80] hover:text-[#f0f0f5]"
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
              </svg>
            </button>

            <div
              className="w-2 h-2 rounded-full mb-3"
              style={{ backgroundColor: selectedEvent.subjectColor }}
            />
            <h3 className="text-[#f0f0f5] font-semibold text-lg mb-1">{selectedEvent.name}</h3>
            <p className="text-[#6b6b80] text-sm mb-4">{selectedEvent.subject}</p>

            <div className="space-y-2 text-sm mb-5">
              <div className="flex justify-between">
                <span className="text-[#6b6b80]">Due date</span>
                <span className="text-[#f0f0f5] font-medium">{formatDate(selectedEvent.dueDate)}</span>
              </div>
              {selectedEvent.startByDate && (
                <div className="flex justify-between">
                  <span className="text-[#6b6b80]">Start by</span>
                  <span className="text-[#22d3a5] font-medium">{formatDate(selectedEvent.startByDate)}</span>
                </div>
              )}
              <div className="flex justify-between">
                <span className="text-[#6b6b80]">Est. time</span>
                <span className="text-[#f0f0f5] font-medium">{selectedEvent.estimatedHours}h</span>
              </div>
              {selectedEvent.notes && (
                <div className="flex justify-between">
                  <span className="text-[#6b6b80]">Notes</span>
                  <span className="text-[#f0f0f5] font-medium text-right max-w-[60%]">{selectedEvent.notes}</span>
                </div>
              )}
            </div>

            <button
              onClick={() => {
                onToggleComplete(selectedEvent.id)
                setSelectedEvent(null)
              }}
              className="w-full py-2.5 rounded-xl bg-[#22d3a5]/10 text-[#22d3a5] font-medium text-sm hover:bg-[#22d3a5]/20 transition-colors border border-[#22d3a5]/20"
            >
              ✓ Mark Complete
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
