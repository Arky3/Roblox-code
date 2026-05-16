import { useState, useEffect, useRef } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { extractAssignments, generateStudyPlan, toBase64 } from '../utils/claude'
import { getSubjectColor } from '../utils/colors'
import { storage } from '../utils/storage'

const LOADING_MESSAGES = [
  'Reading your image...',
  'Finding assignments...',
  'Building your schedule...',
  'Almost done...',
]

const HOUR_OPTIONS = [0.5, 1, 1.5, 2, 3, 4, 5, 6, 8]

export default function Scan({ onAddAssignments }) {
  const { state } = useLocation()
  const navigate = useNavigate()
  const [loading, setLoading] = useState(true)
  const [loadingMsgIdx, setLoadingMsgIdx] = useState(0)
  const [extracted, setExtracted] = useState([])
  const [error, setError] = useState(null)
  const [manualMode, setManualMode] = useState(false)
  const didRun = useRef(false)

  useEffect(() => {
    if (!state?.file) { navigate('/'); return }
    if (didRun.current) return
    didRun.current = true

    const interval = setInterval(() => {
      setLoadingMsgIdx((i) => (i + 1) % LOADING_MESSAGES.length)
    }, 1500)

    const run = async () => {
      try {
        const apiKey = import.meta.env.VITE_ANTHROPIC_API_KEY || storage.getApiKey()
        if (!apiKey) {
          setError('no_api_key')
          setLoading(false)
          clearInterval(interval)
          return
        }

        const base64 = await toBase64(state.file)
        const mimeType = state.file.type || 'image/jpeg'
        const assignments = await extractAssignments(base64, mimeType)

        if (!assignments || assignments.length === 0) {
          setError('no_assignments')
          setLoading(false)
          clearInterval(interval)
          return
        }

        const withIds = assignments.map((a) => ({
          ...a,
          id: crypto.randomUUID(),
          subjectColor: getSubjectColor(a.subject),
          completed: false,
          createdAt: new Date().toISOString(),
        }))

        setExtracted(withIds)
        setLoading(false)
        clearInterval(interval)
      } catch (err) {
        setError(err.message || 'unknown_error')
        setLoading(false)
        clearInterval(interval)
      }
    }

    run()
    return () => clearInterval(interval)
  }, [state, navigate])

  const updateField = (id, field, value) => {
    setExtracted((prev) =>
      prev.map((a) => (a.id === id ? { ...a, [field]: value } : a))
    )
  }

  const removeItem = (id) => {
    setExtracted((prev) => prev.filter((a) => a.id !== id))
  }

  const handleConfirm = async () => {
    if (extracted.length === 0) return
    setLoading(true)
    setLoadingMsgIdx(2)

    try {
      const plan = await generateStudyPlan(extracted)
      const withPlan = extracted.map((a) => {
        const planItem = plan.plan?.find((p) => p.name === a.name)
        return {
          ...a,
          startByDate: planItem?.startByDate || null,
          urgency: planItem?.urgency || 'medium',
        }
      })
      onAddAssignments(withPlan)
      navigate('/dashboard')
    } catch {
      // If study plan fails, still save assignments without plan
      onAddAssignments(extracted)
      navigate('/dashboard')
    }
  }

  const addManualItem = () => {
    const today = new Date()
    today.setDate(today.getDate() + 7)
    const dueDate = today.toISOString().split('T')[0]
    setExtracted((prev) => [
      ...prev,
      {
        id: crypto.randomUUID(),
        name: '',
        subject: '',
        dueDate,
        estimatedHours: 1,
        notes: '',
        subjectColor: getSubjectColor('Other'),
        completed: false,
        createdAt: new Date().toISOString(),
      },
    ])
  }

  if (!state?.file) return null

  return (
    <div className="min-h-screen bg-[#0a0a0f] pt-20 pb-12 px-4">
      <div className="max-w-2xl mx-auto">
        {/* Image preview */}
        {state.previewUrl && (
          <div className="mb-6">
            <img
              src={state.previewUrl}
              alt="Uploaded"
              className="w-full max-h-72 object-contain rounded-2xl border border-[#1e1e2e]"
            />
          </div>
        )}

        {loading && (
          <div className="text-center py-16">
            <div className="flex justify-center gap-2 mb-6">
              {[0, 1, 2].map((i) => (
                <div
                  key={i}
                  className="w-3 h-3 rounded-full bg-[#4f8ef7] animate-bounce"
                  style={{ animationDelay: `${i * 0.15}s` }}
                />
              ))}
            </div>
            <p className="text-[#f0f0f5] font-medium text-lg">{LOADING_MESSAGES[loadingMsgIdx]}</p>
            <p className="text-[#6b6b80] text-sm mt-2">Claude is reading your image</p>
          </div>
        )}

        {!loading && error === 'no_api_key' && (
          <ApiKeyPrompt onSaved={() => { didRun.current = false; window.location.reload() }} />
        )}

        {!loading && error === 'no_assignments' && (
          <div className="text-center py-12">
            <div className="text-4xl mb-4">🔍</div>
            <h2 className="text-[#f0f0f5] font-semibold text-xl mb-2">No assignments found</h2>
            <p className="text-[#6b6b80] mb-6 max-w-sm mx-auto">
              We couldn't find any assignments in that image. Try a clearer photo or add them manually.
            </p>
            <div className="flex gap-3 justify-center">
              <button onClick={() => navigate('/')} className="px-5 py-2.5 rounded-xl text-sm font-medium bg-[#1e1e2e] text-[#6b6b80] hover:text-[#f0f0f5] transition-colors">
                Try another image
              </button>
              <button onClick={() => { setError(null); setManualMode(true); addManualItem() }} className="px-5 py-2.5 rounded-xl text-sm font-medium bg-[#4f8ef7] text-white hover:bg-[#4f8ef7]/90 transition-colors">
                Add manually
              </button>
            </div>
          </div>
        )}

        {!loading && error && error !== 'no_api_key' && error !== 'no_assignments' && (
          <div className="text-center py-12">
            <div className="text-4xl mb-4">⚠️</div>
            <h2 className="text-[#f0f0f5] font-semibold text-xl mb-2">Something went wrong</h2>
            <p className="text-[#6b6b80] mb-2 text-sm max-w-sm mx-auto">{error}</p>
            <div className="flex gap-3 justify-center mt-6">
              <button onClick={() => navigate('/')} className="px-5 py-2.5 rounded-xl text-sm font-medium bg-[#1e1e2e] text-[#6b6b80] hover:text-[#f0f0f5] transition-colors">
                Go back
              </button>
              <button onClick={() => { setError(null); setManualMode(true); addManualItem() }} className="px-5 py-2.5 rounded-xl text-sm font-medium bg-[#4f8ef7] text-white hover:bg-[#4f8ef7]/90 transition-colors">
                Add manually
              </button>
            </div>
          </div>
        )}

        {!loading && !error && (
          <>
            <div className="flex items-center justify-between mb-4">
              <div>
                <h2 className="text-[#f0f0f5] font-semibold text-xl">
                  {extracted.length} assignment{extracted.length !== 1 ? 's' : ''} found
                </h2>
                <p className="text-[#6b6b80] text-sm">Review and edit before adding to your schedule</p>
              </div>
              <button onClick={addManualItem} className="text-sm text-[#4f8ef7] hover:text-[#4f8ef7]/80 font-medium transition-colors">
                + Add more
              </button>
            </div>

            <div className="space-y-3 mb-8">
              {extracted.map((a) => (
                <EditableAssignmentRow
                  key={a.id}
                  assignment={a}
                  onChange={(field, value) => updateField(a.id, field, value)}
                  onRemove={() => removeItem(a.id)}
                />
              ))}
            </div>

            <div className="flex gap-3 sticky bottom-4">
              <button
                onClick={() => navigate('/')}
                className="flex-1 py-3 rounded-xl text-sm font-medium bg-[#1e1e2e] text-[#6b6b80] hover:text-[#f0f0f5] transition-colors"
              >
                Discard
              </button>
              <button
                onClick={handleConfirm}
                disabled={extracted.length === 0}
                className="flex-1 py-3 rounded-xl text-sm font-semibold bg-[#22d3a5] text-[#0a0a0f] hover:bg-[#22d3a5]/90 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
              >
                Add to My Schedule ✓
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

function EditableAssignmentRow({ assignment, onChange, onRemove }) {
  const HOUR_OPTIONS = [0.5, 1, 1.5, 2, 3, 4, 5, 6, 8]
  return (
    <div className="bg-[#13131a] border border-[#1e1e2e] rounded-2xl p-4 space-y-3">
      <div className="flex gap-2">
        <div
          className="w-3 h-3 rounded-full mt-1 flex-shrink-0"
          style={{ backgroundColor: assignment.subjectColor }}
        />
        <input
          type="text"
          value={assignment.name}
          onChange={(e) => onChange('name', e.target.value)}
          placeholder="Assignment name"
          className="flex-1 bg-transparent text-[#f0f0f5] font-medium text-sm focus:outline-none placeholder-[#6b6b80]"
        />
        <button onClick={onRemove} className="text-[#6b6b80] hover:text-[#f75555] transition-colors">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>

      <div className="grid grid-cols-2 gap-2 pl-5">
        <div>
          <label className="text-xs text-[#6b6b80] mb-1 block">Subject</label>
          <input
            type="text"
            value={assignment.subject}
            onChange={(e) => onChange('subject', e.target.value)}
            placeholder="e.g. Biology"
            className="w-full bg-[#0a0a0f] border border-[#1e1e2e] rounded-lg px-3 py-1.5 text-xs text-[#f0f0f5] focus:outline-none focus:border-[#4f8ef7] transition-colors"
          />
        </div>
        <div>
          <label className="text-xs text-[#6b6b80] mb-1 block">Due date</label>
          <input
            type="date"
            value={assignment.dueDate}
            onChange={(e) => onChange('dueDate', e.target.value)}
            className="w-full bg-[#0a0a0f] border border-[#1e1e2e] rounded-lg px-3 py-1.5 text-xs text-[#f0f0f5] focus:outline-none focus:border-[#4f8ef7] transition-colors"
          />
        </div>
        <div>
          <label className="text-xs text-[#6b6b80] mb-1 block">Est. hours</label>
          <select
            value={assignment.estimatedHours}
            onChange={(e) => onChange('estimatedHours', parseFloat(e.target.value))}
            className="w-full bg-[#0a0a0f] border border-[#1e1e2e] rounded-lg px-3 py-1.5 text-xs text-[#f0f0f5] focus:outline-none focus:border-[#4f8ef7] transition-colors"
          >
            {HOUR_OPTIONS.map((h) => (
              <option key={h} value={h}>{h}h</option>
            ))}
          </select>
        </div>
        <div>
          <label className="text-xs text-[#6b6b80] mb-1 block">Notes</label>
          <input
            type="text"
            value={assignment.notes}
            onChange={(e) => onChange('notes', e.target.value)}
            placeholder="Optional"
            className="w-full bg-[#0a0a0f] border border-[#1e1e2e] rounded-lg px-3 py-1.5 text-xs text-[#f0f0f5] focus:outline-none focus:border-[#4f8ef7] transition-colors"
          />
        </div>
      </div>
    </div>
  )
}

function ApiKeyPrompt({ onSaved }) {
  const [key, setKey] = useState('')
  const handleSave = () => {
    if (!key.trim()) return
    storage.saveApiKey(key.trim())
    onSaved()
  }
  return (
    <div className="text-center py-12">
      <div className="text-4xl mb-4">🔑</div>
      <h2 className="text-[#f0f0f5] font-semibold text-xl mb-2">API Key Required</h2>
      <p className="text-[#6b6b80] mb-6 max-w-sm mx-auto text-sm">
        SnapStudy uses the Claude API to read your images. Enter your Anthropic API key to continue.
      </p>
      <div className="max-w-sm mx-auto space-y-3">
        <input
          type="password"
          value={key}
          onChange={(e) => setKey(e.target.value)}
          placeholder="sk-ant-..."
          className="w-full bg-[#13131a] border border-[#1e1e2e] rounded-xl px-4 py-3 text-sm text-[#f0f0f5] placeholder-[#6b6b80] focus:outline-none focus:border-[#4f8ef7] transition-colors font-mono"
          onKeyDown={(e) => e.key === 'Enter' && handleSave()}
        />
        <button
          onClick={handleSave}
          className="w-full py-3 rounded-xl text-sm font-semibold bg-[#4f8ef7] text-white hover:bg-[#4f8ef7]/90 transition-colors"
        >
          Continue
        </button>
      </div>
    </div>
  )
}
