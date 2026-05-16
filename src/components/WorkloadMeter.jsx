import { getTotalHoursThisWeek, getWorkloadColor } from '../utils/scheduling'

export default function WorkloadMeter({ assignments }) {
  const hours = getTotalHoursThisWeek(assignments)
  const max = 20
  const pct = Math.min((hours / max) * 100, 100)
  const color = getWorkloadColor(hours)

  return (
    <div className="mb-4">
      <div className="flex items-center justify-between mb-2">
        <span className="text-xs font-medium text-[#6b6b80] uppercase tracking-wide">This week</span>
        <span className="text-xs font-semibold" style={{ color }}>
          ~{hours.toFixed(1)} hrs of work
        </span>
      </div>
      <div className="h-1.5 bg-[#1e1e2e] rounded-full overflow-hidden">
        <div
          className="h-full rounded-full transition-all duration-500"
          style={{ width: `${pct}%`, backgroundColor: color }}
        />
      </div>
    </div>
  )
}
