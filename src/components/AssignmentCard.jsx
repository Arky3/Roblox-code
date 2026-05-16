import { getDueLabelAndColor, getStartByLabel, formatDate } from '../utils/scheduling'

export default function AssignmentCard({ assignment, onToggleComplete, onDelete }) {
  const { label, color, badge } = getDueLabelAndColor(assignment.dueDate, assignment.completed)
  const startByLabel = getStartByLabel(assignment.startByDate)

  return (
    <div
      className={`group flex gap-3 p-3 rounded-xl border transition-all duration-200 ${
        assignment.completed
          ? 'border-[#1e1e2e] opacity-40'
          : badge === 'OVERDUE'
          ? 'border-[#f75555]/30 bg-[#f75555]/5'
          : badge === 'DUE SOON' || badge === 'DUE TODAY'
          ? 'border-[#f7a844]/30 bg-[#f7a844]/5'
          : 'border-[#1e1e2e] bg-[#13131a] hover:border-[#2a2a3e]'
      }`}
    >
      <div className="flex flex-col items-center gap-1 pt-0.5">
        <button
          onClick={() => onToggleComplete(assignment.id)}
          className={`w-5 h-5 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all ${
            assignment.completed
              ? 'border-[#22d3a5] bg-[#22d3a5]'
              : 'border-[#2a2a3e] hover:border-[#22d3a5]'
          }`}
        >
          {assignment.completed && (
            <svg width="10" height="10" viewBox="0 0 12 12" fill="none">
              <path d="M2 6l3 3 5-5" stroke="#0a0a0f" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          )}
        </button>
        <div
          className="w-0.5 flex-1 rounded-full opacity-60"
          style={{ backgroundColor: assignment.subjectColor || '#4f8ef7', minHeight: '16px' }}
        />
      </div>

      <div className="flex-1 min-w-0">
        <div className="flex items-start justify-between gap-2">
          <p className={`text-sm font-medium text-[#f0f0f5] leading-tight ${assignment.completed ? 'line-through' : ''}`}>
            {assignment.name}
          </p>
          {badge && !assignment.completed && (
            <span
              className="flex-shrink-0 text-[10px] font-bold px-1.5 py-0.5 rounded-md"
              style={{
                color: badge === 'OVERDUE' ? '#f75555' : '#f7a844',
                backgroundColor: badge === 'OVERDUE' ? '#f75555' + '20' : '#f7a844' + '20',
              }}
            >
              {badge}
            </span>
          )}
        </div>

        <div className="flex items-center gap-1.5 mt-1">
          <div
            className="w-2 h-2 rounded-full flex-shrink-0"
            style={{ backgroundColor: assignment.subjectColor || '#4f8ef7' }}
          />
          <span className="text-xs text-[#6b6b80]">{assignment.subject}</span>
          <span className="text-[#2a2a3e]">·</span>
          <span className="text-xs font-medium" style={{ color }}>
            {label}
          </span>
        </div>

        {startByLabel && !assignment.completed && (
          <p className="text-xs text-[#6b6b80] mt-1">{startByLabel}</p>
        )}
      </div>

      {onDelete && (
        <button
          onClick={() => onDelete(assignment.id)}
          className="opacity-0 group-hover:opacity-100 p-1 text-[#6b6b80] hover:text-[#f75555] transition-all flex-shrink-0"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      )}
    </div>
  )
}
