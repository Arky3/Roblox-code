import { useState, useRef, useEffect, useCallback } from 'react'

// ── SYSTEM PROMPT ─────────────────────────────────────────────
const SYSTEM_PROMPT = `You are the engine behind Career Day, an AI-powered career immersion experience. Your job is to drop the user into a realistic workday in an unknown career. They do not know the job title. Do not tell them. Do not hint at it. They discover it by living it.

CORE RULES — NEVER BREAK THESE:
1. Never reveal the career title until the simulation is over.
2. Never make this feel like a quiz, game, or test.
3. Never use XP, points, scores, badges, or signal "correct answers."
4. Never let the user feel like they are being evaluated.
5. Never be generic. Every detail must feel specific and real.
6. Never rush to the reveal. Let the day breathe.

SIMULATION STRUCTURE:
Internally pick ONE career from this list. Keep it completely secret:
— Emergency Room Nurse
— Public Defender
— Software Engineer (early-stage startup, not corporate)
— Investigative Journalist
— UX Designer at a mid-size product company
— High School Teacher (inner-city, underfunded school)
— Structural Engineer on a delayed construction project

Place the user immediately inside a workday — no intro, no preamble, no "welcome to." Start mid-morning. Something is already happening. Write like a novelist. Grounded. Human. Specific. Never clinical.

Every simulation must eventually include:
— A coworker interaction (friction, collaboration, or tension)
— A time-sensitive problem or deadline
— A moment of ambiguity or ethical tradeoff
— A repetitive or boring task (intentional — reveals real fit)
— A high-pressure moment
— An unexpected interruption
— At least one conversation with a manager or client

ADAPTATION RULES — read the user and push accordingly:
— Empathetic responses: deepen social and emotional challenges
— Analytical responses: push with data, ambiguity, logic problems
— Conflict avoidance: make confrontation unavoidable
— Fast and decisive: add consequences to their speed
— Hesitation: add pressure from the environment

EMOTIONAL REALISM:
Include boring, repetitive moments. Include awkward conversations. Include uncertainty. Not every decision has a clear answer. The user's emotional reaction to the day IS the product.

ENDING THE SIMULATION:
After 8–12 meaningful user responses, end the simulation. First deliver any final narrative beat in plain prose. Then — on a new line, with nothing before or after — output the reveal block in EXACTLY this format. Do not add extra keys. Do not wrap in markdown:

[[REVEAL_START]]
{
  "career": "Exact job title",
  "behaviorRecap": [
    "Specific decision or behavior the user actually made (reference their exact words)",
    "Another specific observation from the simulation",
    "A third concrete thing you noticed"
  ],
  "strengths": [
    "A genuine strength that emerged — be specific, not generic",
    "Another real strength"
  ],
  "frictionPoints": [
    "A specific moment of hesitation, stress, or avoidance",
    "Another friction point if there was one — omit if not genuine"
  ],
  "professionalComparison": "One honest paragraph comparing this user's behavior to people who thrive in this field. Be specific. Reference patterns you actually observed. Not everything is a compliment.",
  "adjacentCareers": [
    {"title": "Career title", "reason": "Why — based on their actual behavior, not the job category"},
    {"title": "Career title", "reason": "Why"},
    {"title": "Career title", "reason": "Why"}
  ]
}
[[REVEAL_END]]`

// ── API ───────────────────────────────────────────────────────
function getApiKey() {
  return import.meta.env.VITE_ANTHROPIC_API_KEY || localStorage.getItem('cd_api_key') || ''
}

async function callClaude(messages) {
  const apiKey = getApiKey()
  if (!apiKey) throw new Error('No API key. Enter your Anthropic API key below to begin.')

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'anthropic-dangerous-direct-browser-access': 'true',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-6',
      max_tokens: 1400,
      system: SYSTEM_PROMPT,
      messages,
    }),
  })

  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(err?.error?.message || `API error ${res.status}`)
  }

  const data = await res.json()
  return data.content[0].text
}

// ── REVEAL PARSING ────────────────────────────────────────────
function parseReveal(text) {
  const match = text.match(/\[\[REVEAL_START\]\]([\s\S]*?)\[\[REVEAL_END\]\]/)
  if (!match) return null
  try {
    return JSON.parse(match[1].trim())
  } catch {
    // Try to repair common JSON issues (smart quotes, trailing commas)
    const cleaned = match[1].trim()
      .replace(/[‘’]/g, "'")
      .replace(/[“”]/g, '"')
      .replace(/,(\s*[}\]])/g, '$1')
    try { return JSON.parse(cleaned) } catch { return null }
  }
}

function stripReveal(text) {
  return text.replace(/\[\[REVEAL_START\]\][\s\S]*?\[\[REVEAL_END\]\]/g, '').trim()
}

// ── WELCOME SCREEN ────────────────────────────────────────────
function WelcomeScreen({ onStart, error }) {
  const [keyInput, setKeyInput] = useState('')
  const [saved, setSaved] = useState(false)
  const hasKey = !!getApiKey()

  function saveKey() {
    const trimmed = keyInput.trim()
    if (!trimmed) return
    localStorage.setItem('cd_api_key', trimmed)
    setSaved(true)
    setKeyInput('')
  }

  return (
    <div className="welcome-screen">
      <div className="welcome-content">
        <div className="wordmark">Career Day</div>
        <p className="tagline">Live a career before choosing it.</p>
        <p className="sub-tagline">
          You'll be dropped into a real workday in an unknown field.
          No title. No hints. No quiz. Just the work — and how you handle it.
        </p>

        <button className="btn-start" onClick={onStart}>
          Begin Your Day
        </button>

        {error && (
          <div className="error-box" style={{ marginBottom: 16, textAlign: 'left' }}>
            {error}
          </div>
        )}

        {!hasKey && !saved && (
          <div className="api-key-section">
            <div className="api-key-label">Anthropic API Key</div>
            <div className="api-key-row">
              <input
                className="api-key-input"
                type="password"
                placeholder="sk-ant-..."
                value={keyInput}
                onChange={e => setKeyInput(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && saveKey()}
              />
              <button className="api-key-save" onClick={saveKey}>Save</button>
            </div>
            <p className="api-key-note">
              Stored locally in your browser. Never sent anywhere except Anthropic.
            </p>
          </div>
        )}

        {saved && (
          <p className="api-key-note" style={{ color: 'var(--green)', marginTop: 8 }}>
            Key saved. Click Begin Your Day.
          </p>
        )}
      </div>
    </div>
  )
}

// ── SIMULATION SCREEN ─────────────────────────────────────────
function SimulationScreen({ messages, onSend, isLoading, onQuit }) {
  const [input, setInput] = useState('')
  const endRef = useRef(null)
  const textareaRef = useRef(null)

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, isLoading])

  function handleSend() {
    const text = input.trim()
    if (!text || isLoading) return
    onSend(text)
    setInput('')
    // Reset textarea height
    if (textareaRef.current) textareaRef.current.style.height = 'auto'
  }

  function handleKeyDown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  function autoResize(e) {
    e.target.style.height = 'auto'
    e.target.style.height = Math.min(e.target.scrollHeight, 130) + 'px'
  }

  return (
    <div className="sim-screen">
      <div className="sim-header">
        <span className="sim-wordmark">Career Day</span>
        <button className="sim-end-btn" onClick={onQuit}>Quit</button>
      </div>

      <div className="sim-messages">
        {messages.map((m, i) => (
          <div key={i} className={`message ${m.role}`}>
            {m.role === 'assistant'
              ? <div className="narrative">{m.content}</div>
              : <div className="user-bubble">{m.content}</div>
            }
          </div>
        ))}

        {isLoading && (
          <div className="message assistant">
            <div className="typing"><span /><span /><span /></div>
          </div>
        )}

        <div ref={endRef} />
      </div>

      <div className="sim-input-area">
        <textarea
          ref={textareaRef}
          className="sim-textarea"
          placeholder="What do you do?"
          value={input}
          onChange={e => { setInput(e.target.value); autoResize(e) }}
          onKeyDown={handleKeyDown}
          rows={1}
          disabled={isLoading}
        />
        <button
          className="send-btn"
          onClick={handleSend}
          disabled={isLoading || !input.trim()}
        >
          →
        </button>
      </div>
    </div>
  )
}

// ── REVEAL SCREEN ─────────────────────────────────────────────
function RevealScreen({ reveal, lastNarrative, onPlayAgain }) {
  const [visible, setVisible] = useState(false)
  const [response, setResponse] = useState('')
  const [submitted, setSubmitted] = useState(false)

  useEffect(() => {
    const t = setTimeout(() => setVisible(true), 600)
    return () => clearTimeout(t)
  }, [])

  const frictionPoints = reveal.frictionPoints?.filter(Boolean) ?? []

  return (
    <div className="reveal-screen">
      <div className="reveal-content">
        {lastNarrative && (
          <div className="narrative" style={{
            fontFamily: 'var(--serif)',
            fontSize: 17,
            lineHeight: 1.9,
            color: 'var(--text-muted)',
            marginBottom: 52,
            whiteSpace: 'pre-wrap',
          }}>
            {lastNarrative}
          </div>
        )}

        <div className="reveal-kicker">You just spent a day as a</div>
        <div className="reveal-title">{reveal.career}</div>

        <div className={`reveal-details ${visible ? 'visible' : ''}`}>

          {/* What you did */}
          {reveal.behaviorRecap?.length > 0 && (
            <div className="reveal-section">
              <div className="reveal-section-label">What you did</div>
              {reveal.behaviorRecap.map((item, i) => (
                <div key={i} className="reveal-item">
                  <span className="reveal-dash">—</span>
                  <span>{item}</span>
                </div>
              ))}
            </div>
          )}

          {/* Strengths */}
          {reveal.strengths?.length > 0 && (
            <div className="reveal-section">
              <div className="reveal-section-label">Where you showed up</div>
              {reveal.strengths.map((s, i) => (
                <div key={i} className="reveal-strength-item">{s}</div>
              ))}
            </div>
          )}

          {/* Friction */}
          {frictionPoints.length > 0 && (
            <div className="reveal-section">
              <div className="reveal-section-label">Where you hesitated</div>
              {frictionPoints.map((f, i) => (
                <div key={i} className="reveal-friction-item">{f}</div>
              ))}
            </div>
          )}

          {/* Professional comparison */}
          {reveal.professionalComparison && (
            <div className="reveal-comparison">{reveal.professionalComparison}</div>
          )}

          {/* Adjacent careers */}
          {reveal.adjacentCareers?.length > 0 && (
            <div className="reveal-section">
              <div className="reveal-section-label">You might also connect with</div>
              <div>
                {reveal.adjacentCareers.map((c, i) => (
                  <div key={i} className="adjacent-item">
                    <div className="adjacent-title">{c.title}</div>
                    <div className="adjacent-reason">{c.reason}</div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Final question */}
          <div className="final-question">
            Could you see yourself doing this every day?
          </div>

          {!submitted ? (
            <div className="final-response-area">
              <textarea
                className="final-textarea"
                placeholder="Take your time..."
                value={response}
                onChange={e => setResponse(e.target.value)}
                rows={4}
              />
              {response.trim() && (
                <button className="btn-submit" onClick={() => setSubmitted(true)}>
                  That's my answer
                </button>
              )}
            </div>
          ) : (
            <div className="final-submitted">
              <div className="final-submitted-quote">"{response}"</div>
              <button className="btn-again" onClick={onPlayAgain}>
                Try another career →
              </button>
            </div>
          )}

        </div>
      </div>
    </div>
  )
}

// ── ROOT APP ──────────────────────────────────────────────────
export default function App() {
  const [screen, setScreen] = useState('welcome')
  const [messages, setMessages] = useState([])
  const [isLoading, setIsLoading] = useState(false)
  const [reveal, setReveal] = useState(null)
  const [lastNarrative, setLastNarrative] = useState('')
  const [error, setError] = useState('')

  const handleResponse = useCallback((rawText, priorMessages) => {
    const revealData = parseReveal(rawText)
    const display = stripReveal(rawText)

    if (revealData) {
      // There may be a final narrative beat before the reveal block
      setLastNarrative(display)
      setReveal(revealData)
      setMessages(priorMessages)
      setScreen('reveal')
    } else {
      setMessages([...priorMessages, { role: 'assistant', content: display }])
    }
  }, [])

  async function startSimulation() {
    setError('')
    setMessages([])
    setReveal(null)
    setLastNarrative('')
    setScreen('simulation')
    setIsLoading(true)

    try {
      const rawText = await callClaude([{ role: 'user', content: 'Begin.' }])
      handleResponse(rawText, [])
    } catch (e) {
      setError(e.message)
      setScreen('welcome')
    } finally {
      setIsLoading(false)
    }
  }

  async function handleSend(userText) {
    const newMessages = [...messages, { role: 'user', content: userText }]
    setMessages(newMessages)
    setIsLoading(true)

    try {
      const rawText = await callClaude(
        newMessages.map(m => ({ role: m.role, content: m.content }))
      )
      handleResponse(rawText, newMessages)
    } catch (e) {
      setMessages([...newMessages, {
        role: 'assistant',
        content: `Something went wrong: ${e.message}`,
      }])
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="app">
      {screen === 'welcome' && (
        <WelcomeScreen onStart={startSimulation} error={error} />
      )}
      {screen === 'simulation' && (
        <SimulationScreen
          messages={messages}
          onSend={handleSend}
          isLoading={isLoading}
          onQuit={() => setScreen('welcome')}
        />
      )}
      {screen === 'reveal' && reveal && (
        <RevealScreen
          reveal={reveal}
          lastNarrative={lastNarrative}
          onPlayAgain={startSimulation}
        />
      )}
    </div>
  )
}
