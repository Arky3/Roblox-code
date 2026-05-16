import { useState, useEffect, useRef, useCallback } from 'react'

// ─────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────
const CONDITIONS = [
  'Acne','Rosacea','Eczema','Psoriasis','Seborrheic Dermatitis',
  'Hives','Contact Dermatitis','Perioral Dermatitis','Folliculitis',
  'Dry Skin','Oily Skin','Sensitive Skin','Other',
]

const CONDITION_BEST = {
  'Acne':                   { diet:'Low Glycemic',       reason:'Reduces insulin spikes that trigger excess sebum production' },
  'Rosacea':                { diet:'Anti-Inflammatory',  reason:'Calms vascular inflammation that causes flushing and redness' },
  'Eczema':                 { diet:'Elimination',        reason:'Identifies and removes dietary triggers causing barrier dysfunction' },
  'Psoriasis':              { diet:'Anti-Inflammatory',  reason:'Reduces systemic inflammation driving skin-cell overproduction' },
  'Seborrheic Dermatitis':  { diet:'Anti-Inflammatory',  reason:'Reduces the inflammatory response that triggers yeast overgrowth' },
  'Hives':                  { diet:'Elimination',        reason:'Removes histamine-triggering foods causing allergic skin reactions' },
  'Contact Dermatitis':     { diet:'Anti-Inflammatory',  reason:'Supports the skin barrier and reduces inflammatory sensitization' },
  'Perioral Dermatitis':    { diet:'Elimination',        reason:'Identifies topical and dietary triggers around the mouth' },
  'Folliculitis':           { diet:'Low Glycemic',       reason:'Reduces blood-sugar spikes that feed bacteria in hair follicles' },
  'Dry Skin':               { diet:'Mediterranean',      reason:'Rich in essential fatty acids that maintain the skin moisture barrier' },
  'Oily Skin':              { diet:'Low Glycemic',       reason:'Controls sebum overproduction by stabilizing insulin levels' },
  'Sensitive Skin':         { diet:'Plant-Based',        reason:'Eliminates common irritants while providing anti-inflammatory phytonutrients' },
  'Other':                  { diet:'Mediterranean',      reason:'Broadly anti-inflammatory with proven skin-health benefits' },
}

const DIETS = [
  { id:'Mediterranean',       emoji:'🫒', desc:'Olive oil, fish, vegetables, legumes',     budget:true,  solo:false },
  { id:'Anti-Inflammatory',   emoji:'🫚', desc:'Antioxidant-rich, omega-3 focused',        budget:false, solo:false },
  { id:'Low Glycemic',        emoji:'📉', desc:'Stable blood sugar, minimal refined carbs', budget:true,  solo:false },
  { id:'Plant-Based',         emoji:'🌱', desc:'Whole foods, plant proteins, fiber-rich',  budget:true,  solo:false },
  { id:'Elimination',         emoji:'🚫', desc:'Remove triggers, reintroduce slowly',      budget:false, solo:true  },
  { id:'Ketogenic',           emoji:'🥑', desc:'Very low carb, high fat, metabolic reset', budget:false, solo:true  },
  { id:'Paleo',               emoji:'🥩', desc:'Ancestral eating, no processed foods',     budget:false, solo:true  },
  { id:'DASH',                emoji:'🫀', desc:'Heart-healthy, low sodium, balanced',      budget:true,  solo:false },
  { id:'Whole30',             emoji:'🌾', desc:'30-day reset — no grains, dairy or sugar', budget:false, solo:true  },
  { id:'High-Protein',        emoji:'💪', desc:'Muscle-supportive, satiety-focused',       budget:true,  solo:false },
  { id:'Intermittent Fasting',emoji:'⏱️', desc:'Time-restricted eating, cellular autophagy',budget:false,solo:false },
  { id:'Vegan',               emoji:'🌿', desc:'100% plant foods, ethical & anti-inflammatory',budget:true,solo:false },
]
const SOLO_DIETS = ['Elimination','Ketogenic','Paleo','Whole30']

const ALLERGY_CHIPS  = ['Tree Nuts','Peanuts','Dairy','Gluten','Eggs','Shellfish','Fish','Soy','Sesame']
const HEALTH_CHIPS   = ['Diabetes','High Cholesterol','High Blood Pressure','Thyroid Disorder','PCOS','IBS/Gut Issues','Insulin Resistance','Arthritis','Anxiety/Stress']
const DAYS           = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday']
const DAY_FULL       = { monday:'Monday',tuesday:'Tuesday',wednesday:'Wednesday',thursday:'Thursday',friday:'Friday',saturday:'Saturday',sunday:'Sunday' }
const MEAL_SLOTS     = ['breakfast','lunch','dinner','snack']
const MEAL_ICONS     = { breakfast:'☀️', lunch:'🌤️', dinner:'🌙', snack:'🍎' }
const GROCERY_GROUPS = ['Produce','Proteins','Grains & Carbs','Dairy & Alternatives','Pantry','Other']

// ─────────────────────────────────────────────────────────────
// UTILITIES
// ─────────────────────────────────────────────────────────────
function repairJSON(str) {
  str = str.replace(/^```json\s*/m,'').replace(/```\s*$/m,'').trim()
  try { return JSON.parse(str) } catch {}
  const start = str.indexOf('{')
  if (start === -1) return null
  for (let end = str.length; end > start; end--) {
    try { return JSON.parse(str.slice(start,end)) } catch {}
  }
  return null
}

async function callClaude(messages, systemPrompt, maxTokens) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'anthropic-dangerous-direct-browser-access': 'true',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: maxTokens,
      system: systemPrompt,
      messages,
    }),
  })
  if (!res.ok) {
    const err = await res.json().catch(()=>({}))
    throw new Error(err.error?.message || `API error ${res.status}`)
  }
  const data = await res.json()
  return data.content[0].text
}

function buildSystemPrompt(profile, selectedDiets) {
  const excl = []
  if (profile.healthConditions.includes('IBS/Gut Issues'))        excl.push('no garlic, onion, beans, or high-FODMAP foods')
  if (profile.healthConditions.includes('Diabetes'))              excl.push('no high-glycemic foods even if skin-beneficial')
  if (profile.healthConditions.includes('High Cholesterol'))      excl.push('no saturated fats')
  if (profile.healthConditions.includes('Arthritis'))             excl.push('no nightshades (tomatoes, peppers, eggplant)')
  if (profile.healthConditions.includes('PCOS'))                  excl.push('no refined carbohydrates')
  if (profile.healthConditions.includes('High Blood Pressure'))   excl.push('no high-sodium foods')
  if (profile.healthConditions.includes('Thyroid Disorder'))      excl.push('limit raw cruciferous vegetables')
  const allAllergies = [...profile.allergies, ...(profile.otherAllergies||[])]
  const allHealth    = [...profile.healthConditions, ...(profile.otherHealth||[])]
  return `You are an expert dermatology nutritionist and meal planner.
Primary focus: ${profile.condition} skin condition management through diet.
Patient: ${profile.age}yo, ${profile.sex}.
Diet plan: ${selectedDiets.join(' + ')}.
${allAllergies.length ? `STRICT ALLERGIES — never include: ${allAllergies.join(', ')}.` : ''}
${allHealth.length    ? `Health considerations: ${allHealth.join(', ')}.`                : ''}
${excl.length         ? `HARD EXCLUSIONS: ${excl.join('; ')}.`                          : ''}
${profile.budgetMode  ? 'BUDGET MODE: restrict meals to eggs, canned fish, lentils, oats, rice, frozen vegetables, chicken thighs. No salmon fillets, avocado, açaí, or specialty items.' : ''}
Skin condition is ALWAYS the primary focus. Health considerations are secondary modifiers.
Return ONLY compact JSON — no markdown fences, no preamble, no explanation.`
}

function buildPlanPrompt(profile, selectedDiets) {
  return `Generate a complete 8-week dermatology nutrition plan. Return ONLY this JSON (no other text):
{
  "name":"program name up to 50 chars",
  "tagline":"tagline up to 60 chars",
  "duration":"8 weeks",
  "summary":"2-3 sentence program summary",
  "skinFocus":"1 sentence on how this targets ${profile.condition}",
  "alsoConsidered":"1 sentence on health modifiers, or null",
  "principles":["principle 1","principle 2","principle 3","principle 4"],
  "timeline":[
    {"phase":"Phase 1: Elimination / Introduction","weeks":"Weeks 1-2","actions":["a1","a2","a3","a4"]},
    {"phase":"Phase 2: Building","weeks":"Weeks 3-5","actions":["a1","a2","a3","a4"]},
    {"phase":"Phase 3: Maintenance","weeks":"Weeks 6-8","actions":["a1","a2","a3","a4"]}
  ],
  "week1":{
    "monday":{"breakfast":"","lunch":"","dinner":"","snack":""},
    "tuesday":{"breakfast":"","lunch":"","dinner":"","snack":""},
    "wednesday":{"breakfast":"","lunch":"","dinner":"","snack":""},
    "thursday":{"breakfast":"","lunch":"","dinner":"","snack":""},
    "friday":{"breakfast":"","lunch":"","dinner":"","snack":""},
    "saturday":{"breakfast":"","lunch":"","dinner":"","snack":""},
    "sunday":{"breakfast":"","lunch":"","dinner":"","snack":""}
  },
  "eatFoods":[
    {"food":"name","reason":"reason up to 50 chars"},
    {"food":"name","reason":"reason up to 50 chars"},
    {"food":"name","reason":"reason up to 50 chars"},
    {"food":"name","reason":"reason up to 50 chars"},
    {"food":"name","reason":"reason up to 50 chars"},
    {"food":"name","reason":"reason up to 50 chars"}
  ],
  "avoidFoods":[
    {"food":"name","reason":"reason up to 50 chars"},
    {"food":"name","reason":"reason up to 50 chars"},
    {"food":"name","reason":"reason up to 50 chars"},
    {"food":"name","reason":"reason up to 50 chars"},
    {"food":"name","reason":"reason up to 50 chars"},
    {"food":"name","reason":"reason up to 50 chars"}
  ]
}`
}

// ─────────────────────────────────────────────────────────────
// SMALL SHARED COMPONENTS
// ─────────────────────────────────────────────────────────────
function Dots({ color='currentColor' }) {
  return (
    <span className="dd-dots" style={{color}}>
      <span/><span/><span/>
    </span>
  )
}

function Spinner({ size=24, pad=24 }) {
  return (
    <div style={{display:'flex',justifyContent:'center',padding:pad}}>
      <div className="dd-spinner" style={{width:size,height:size}}/>
    </div>
  )
}

function ErrorMsg({ msg, onRetry }) {
  return (
    <div className="error-box">
      <span style={{flexShrink:0}}>⚠️</span>
      <div>
        <div style={{marginBottom:onRetry?6:0}}>{msg}</div>
        {onRetry && (
          <button onClick={onRetry}
            style={{fontSize:12,padding:'3px 10px',border:'1px solid #F5C6C6',borderRadius:6,background:'transparent',color:'var(--error)',cursor:'pointer'}}>
            Try again
          </button>
        )}
      </div>
    </div>
  )
}

function Badge({ children, bg='var(--sage)', color='white', style:s={} }) {
  return (
    <span style={{
      display:'inline-flex',alignItems:'center',
      padding:'3px 10px',borderRadius:20,
      fontSize:11,fontWeight:700,letterSpacing:'.3px',
      background:bg,color,...s,
    }}>
      {children}
    </span>
  )
}

function Label({ children }) {
  return (
    <div style={{fontSize:12,fontWeight:700,color:'var(--muted)',textTransform:'uppercase',letterSpacing:'.6px',marginBottom:6}}>
      {children}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// WELCOME SCREEN
// ─────────────────────────────────────────────────────────────
function WelcomeScreen({ onStart }) {
  const features = [
    { icon:'🌿', label:'Skin-personalized nutrition plans'  },
    { icon:'📅', label:'7-day meals with full recipes'      },
    { icon:'🛒', label:'Smart grouped grocery list'         },
    { icon:'🤖', label:'AI nutritionist chat'               },
    { icon:'💰', label:'Budget-friendly mode'               },
  ]
  return (
    <div className="screen" style={{display:'flex',flexDirection:'column',padding:'0 24px',background:'var(--cream)'}}>
      <div style={{flex:1,display:'flex',flexDirection:'column',justifyContent:'center',paddingTop:72,paddingBottom:40}}>
        <div className="anim-fade-up" style={{fontSize:52,marginBottom:24}}>🌿</div>

        <div className="dd-wordmark anim-fade-up" style={{fontSize:46,marginBottom:14,animationDelay:'.06s'}}>
          <span className="derm">Derm</span><span className="diet">Diet</span>
        </div>

        <p className="anim-fade-up" style={{
          fontFamily:"'Cormorant Garamond',serif",fontStyle:'italic',
          fontSize:19,color:'var(--muted)',lineHeight:1.5,marginBottom:40,
          animationDelay:'.1s',
        }}>
          AI-powered nutrition plans tailored to your skin condition
        </p>

        <div className="anim-fade-up" style={{display:'flex',flexDirection:'column',gap:13,marginBottom:52,animationDelay:'.14s'}}>
          {features.map((f,i) => (
            <div key={i} style={{display:'flex',alignItems:'center',gap:14}}>
              <div style={{
                width:40,height:40,flexShrink:0,
                background:'rgba(74,103,65,.1)',borderRadius:12,
                display:'flex',alignItems:'center',justifyContent:'center',fontSize:20,
              }}>
                {f.icon}
              </div>
              <span style={{fontSize:15,fontWeight:500,color:'var(--bark)'}}>{f.label}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="anim-fade-up" style={{paddingBottom:48,animationDelay:'.3s'}}>
        <button className="btn-primary" style={{width:'100%',padding:'16px 24px',fontSize:16}} onClick={onStart}>
          Get Started →
        </button>
        <p style={{textAlign:'center',color:'var(--muted)',fontSize:12,marginTop:12}}>
          Free · No account required · Powered by Claude AI
        </p>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// COLLAPSIBLE SECTION
// ─────────────────────────────────────────────────────────────
function Collapsible({ title, badge, highlight, children, defaultOpen=false }) {
  const [open,setOpen] = useState(defaultOpen)
  return (
    <div className={`collapsible${highlight?' hi':''}`}>
      <div
        style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'16px 20px',cursor:'pointer',userSelect:'none'}}
        onClick={()=>setOpen(o=>!o)}
      >
        <div style={{display:'flex',alignItems:'center',gap:10}}>
          <span style={{fontSize:15,fontWeight:600}}>{title}</span>
          {badge>0 && <Badge style={{padding:'2px 8px',fontSize:11}}>{badge}</Badge>}
        </div>
        <span style={{color:'var(--muted)',fontSize:14,transition:'transform .3s',transform:open?'rotate(180deg)':'none'}}>▾</span>
      </div>
      {open && <div style={{padding:'0 20px 20px'}}>{children}</div>}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// CHIP GRID WITH "OTHER" TAG INPUT
// ─────────────────────────────────────────────────────────────
function ChipGrid({ options, selected, onToggle, customItems=[], onCustom }) {
  const [otherOpen,setOtherOpen] = useState(false)
  const [val,setVal] = useState('')
  return (
    <div>
      <div style={{display:'flex',flexWrap:'wrap',gap:8,marginBottom:8}}>
        {options.map(opt=>(
          <button key={opt} className={`dd-chip${selected.includes(opt)?' active':''}`} onClick={()=>onToggle(opt)}>
            {opt}
          </button>
        ))}
        {onCustom && (
          <button className={`dd-chip${otherOpen?' active':''}`} onClick={()=>setOtherOpen(o=>!o)}>
            + Other
          </button>
        )}
      </div>
      {customItems.length>0 && (
        <div style={{display:'flex',flexWrap:'wrap',gap:6,marginBottom:8}}>
          {customItems.map((item,i)=>(
            <span key={i} className="dd-chip active" style={{fontSize:12}}>
              {item}
              <span onClick={()=>onCustom('remove',item)} style={{cursor:'pointer',marginLeft:4,opacity:.8}}>×</span>
            </span>
          ))}
        </div>
      )}
      {otherOpen && onCustom && (
        <input
          className="dd-input"
          placeholder="Type and press Enter…"
          value={val}
          onChange={e=>setVal(e.target.value)}
          onKeyDown={e=>{
            if(e.key==='Enter'&&val.trim()){ onCustom('add',val.trim()); setVal('') }
          }}
          style={{fontSize:13}}
        />
      )}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// PROFILE SCREEN
// ─────────────────────────────────────────────────────────────
function ProfileScreen({ profile, setProfile, onNext }) {
  const u = (k,v) => setProfile(p=>({...p,[k]:v}))
  const toggleA = item => setProfile(p=>({...p, allergies: p.allergies.includes(item)?p.allergies.filter(a=>a!==item):[...p.allergies,item]}))
  const toggleH = item => setProfile(p=>({...p, healthConditions: p.healthConditions.includes(item)?p.healthConditions.filter(h=>h!==item):[...p.healthConditions,item]}))
  const handleOA = (action,item) => setProfile(p=>({...p, otherAllergies: action==='add'?[...(p.otherAllergies||[]),item]:(p.otherAllergies||[]).filter(i=>i!==item)}))
  const handleOH = (action,item) => setProfile(p=>({...p, otherHealth: action==='add'?[...(p.otherHealth||[]),item]:(p.otherHealth||[]).filter(i=>i!==item)}))
  const valid = profile.condition && profile.age && profile.sex

  return (
    <div className="screen">
      <div style={{padding:'52px 20px 20px',background:'var(--card)',borderBottom:'1px solid var(--border)'}}>
        <div className="dd-wordmark" style={{fontSize:26,marginBottom:4}}>
          <span className="derm">Derm</span><span className="diet">Diet</span>
        </div>
        <p style={{color:'var(--muted)',fontSize:13}}>Tell us about yourself</p>
      </div>

      <div style={{padding:'18px 20px 0'}}>
        <div className="step-dots">
          <div className="step-dot active"/>
          <div className="step-dot"/>
          <div className="step-dot"/>
        </div>
      </div>

      <div style={{padding:'16px 20px 120px',display:'flex',flexDirection:'column',gap:12}}>
        <div className="card">
          <Label>Skin Condition</Label>
          <select className="dd-input dd-select" value={profile.condition} onChange={e=>u('condition',e.target.value)}>
            <option value="">Select your condition…</option>
            {CONDITIONS.map(c=><option key={c}>{c}</option>)}
          </select>
          {profile.condition==='Other' && (
            <input className="dd-input" placeholder="Describe your skin concern…"
              value={profile.conditionOther||''} onChange={e=>u('conditionOther',e.target.value)} style={{marginTop:10}}/>
          )}
        </div>

        <div className="card" style={{display:'flex',flexDirection:'column',gap:14}}>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:12}}>
            <div>
              <Label>Age</Label>
              <input className="dd-input" type="number" min="1" max="120" placeholder="e.g. 28"
                value={profile.age} onChange={e=>u('age',e.target.value)}/>
            </div>
            <div>
              <Label>Sex</Label>
              <select className="dd-input dd-select" value={profile.sex} onChange={e=>u('sex',e.target.value)}>
                <option value="">Select…</option>
                <option>Male</option><option>Female</option><option>Other</option>
              </select>
            </div>
          </div>

          <div style={{
            display:'flex',alignItems:'center',justifyContent:'space-between',
            padding:'14px 16px',borderRadius:12,border:'1px solid',
            background:profile.budgetMode?'rgba(138,106,16,.07)':'rgba(74,103,65,.04)',
            borderColor:profile.budgetMode?'rgba(138,106,16,.3)':'var(--border)',
            transition:'all .25s',
          }}>
            <div>
              <div style={{fontSize:14,fontWeight:600}}>💰 Budget-Friendly Mode</div>
              <div style={{fontSize:12,color:'var(--muted)',marginTop:3}}>Eggs, lentils, oats, frozen veg &amp; more</div>
            </div>
            <div className={`dd-toggle${profile.budgetMode?' on':''}`} onClick={()=>u('budgetMode',!profile.budgetMode)}/>
          </div>
        </div>

        <Collapsible
          title="Allergies & Intolerances"
          badge={profile.allergies.length+(profile.otherAllergies?.length||0)}
          highlight={profile.allergies.length>0||(profile.otherAllergies?.length||0)>0}
        >
          <ChipGrid options={ALLERGY_CHIPS} selected={profile.allergies} onToggle={toggleA}
            customItems={profile.otherAllergies||[]} onCustom={handleOA}/>
        </Collapsible>

        <Collapsible
          title="Health Considerations"
          badge={profile.healthConditions.length+(profile.otherHealth?.length||0)}
          highlight={profile.healthConditions.length>0||(profile.otherHealth?.length||0)>0}
        >
          <p style={{fontSize:12,color:'var(--muted)',marginBottom:12}}>Skin health stays primary — these are secondary modifiers</p>
          <ChipGrid options={HEALTH_CHIPS} selected={profile.healthConditions} onToggle={toggleH}
            customItems={profile.otherHealth||[]} onCustom={handleOH}/>
        </Collapsible>
      </div>

      <div className="sticky-footer">
        <button className="btn-primary" style={{width:'100%'}} disabled={!valid} onClick={onNext}>
          Choose Your Diet →
        </button>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// DIET SELECTION SCREEN
// ─────────────────────────────────────────────────────────────
function DietScreen({ profile, selectedDiets, setSelectedDiets, onGenerate, generating, genError }) {
  const rec = CONDITION_BEST[profile.condition] || CONDITION_BEST['Other']

  function isDisabled(diet) {
    if (selectedDiets.includes(diet.id)) return false
    if (selectedDiets.length>=2) return true
    const hasSolo = selectedDiets.some(d=>SOLO_DIETS.includes(d))
    if (hasSolo) return true
    if (SOLO_DIETS.includes(diet.id) && selectedDiets.length>0) return true
    return false
  }

  function toggleDiet(id) {
    setSelectedDiets(prev=>{
      if (prev.includes(id)) return prev.filter(d=>d!==id)
      if (prev.length>=2) return prev
      if (SOLO_DIETS.includes(id)) return [id]
      if (prev.some(d=>SOLO_DIETS.includes(d))) return prev
      return [...prev,id]
    })
  }

  return (
    <div className="screen">
      <div style={{padding:'52px 20px 16px',background:'var(--card)',borderBottom:'1px solid var(--border)'}}>
        <div style={{fontSize:12,color:'var(--muted)',marginBottom:10,display:'flex',alignItems:'center',gap:6,flexWrap:'wrap'}}>
          <span>{profile.condition}</span>
          <span>·</span>
          <span>{profile.age}yo {profile.sex}</span>
          {profile.budgetMode && <Badge bg='var(--amber)' style={{marginLeft:2}}>💰 Budget</Badge>}
        </div>
        <h1 style={{fontSize:22,fontWeight:700,marginBottom:4}}>Choose Your Diet</h1>
        <p style={{color:'var(--muted)',fontSize:13}}>Select up to 2 compatible diets</p>
      </div>

      <div style={{padding:'18px 20px 0'}}>
        <div className="step-dots">
          <div className="step-dot done"/>
          <div className="step-dot active"/>
          <div className="step-dot"/>
        </div>
      </div>

      <div style={{padding:'16px 20px 120px'}}>
        {rec && (
          <div style={{background:'rgba(74,103,65,.08)',border:'1.5px solid var(--sage)',borderRadius:14,padding:'14px 16px',marginBottom:16}}>
            <div style={{fontSize:11,fontWeight:700,color:'var(--sage)',textTransform:'uppercase',letterSpacing:'.5px',marginBottom:4}}>
              ✦ Best for {profile.condition}
            </div>
            <div style={{fontSize:14,fontWeight:700,color:'var(--bark)',marginBottom:2}}>{rec.diet}</div>
            <div style={{fontSize:13,color:'var(--muted)',fontStyle:'italic'}}>"{rec.reason}"</div>
          </div>
        )}

        <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}>
          {DIETS.map(diet=>{
            const sel = selectedDiets.includes(diet.id)
            const dis = isDisabled(diet)
            const isRec = diet.id===rec?.diet
            return (
              <div key={diet.id}
                className={`diet-card${sel?' selected':''}${dis?' disabled':''}`}
                onClick={()=>!dis&&toggleDiet(diet.id)}
              >
                {isRec && (
                  <div style={{position:'absolute',top:-9,right:8}}>
                    <Badge style={{fontSize:10,padding:'2px 7px'}}>✦ Recommended</Badge>
                  </div>
                )}
                <div style={{fontSize:26,marginBottom:8}}>{diet.emoji}</div>
                <div style={{fontSize:13,fontWeight:700,color:'var(--bark)',marginBottom:4}}>{diet.id}</div>
                <div style={{fontSize:11,color:'var(--muted)',lineHeight:1.4,marginBottom:8}}>{diet.desc}</div>
                <div style={{display:'flex',gap:4,flexWrap:'wrap'}}>
                  {diet.budget && (
                    <span style={{fontSize:10,background:'rgba(138,106,16,.1)',color:'var(--amber)',padding:'2px 6px',borderRadius:4,fontWeight:700}}>
                      💰 Budget
                    </span>
                  )}
                  {diet.solo && (
                    <span style={{fontSize:10,background:'rgba(74,103,65,.1)',color:'var(--sage)',padding:'2px 6px',borderRadius:4,fontWeight:700}}>
                      Solo only
                    </span>
                  )}
                  {sel && (
                    <span style={{fontSize:10,background:'var(--sage)',color:'white',padding:'2px 6px',borderRadius:4,fontWeight:700}}>
                      ✓ Selected
                    </span>
                  )}
                </div>
              </div>
            )
          })}
        </div>

        {selectedDiets.length===2 && !selectedDiets.some(d=>SOLO_DIETS.includes(d)) && (
          <div style={{marginTop:12,background:'rgba(74,103,65,.06)',borderRadius:10,padding:'10px 14px',textAlign:'center',fontSize:13,color:'var(--sage)',fontWeight:600}}>
            {selectedDiets.join(' + ')} — Great combination ✓
          </div>
        )}

        {genError && <div style={{marginTop:12}}><ErrorMsg msg={genError} onRetry={onGenerate}/></div>}
      </div>

      <div className="sticky-footer">
        <button className="btn-primary" style={{width:'100%'}} disabled={!selectedDiets.length||generating} onClick={onGenerate}>
          {generating ? <><Dots/>&nbsp;Generating your plan…</> : 'Generate My Plan →'}
        </button>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// LOADING SCREEN
// ─────────────────────────────────────────────────────────────
function LoadingScreen({ profile, selectedDiets }) {
  const steps = [
    'Analyzing your skin condition…',
    `Personalizing for ${profile.condition}…`,
    `Building ${selectedDiets.join(' + ')} plan…`,
    'Applying dietary restrictions…',
    'Crafting 7-day meal plan…',
    'Finalizing your plan…',
  ]
  const [step,setStep] = useState(0)
  useEffect(()=>{
    const id = setInterval(()=>setStep(s=>Math.min(s+1,steps.length-1)),1300)
    return ()=>clearInterval(id)
  },[])

  return (
    <div className="screen" style={{display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',padding:40}}>
      <div className="dd-wordmark" style={{fontSize:38,marginBottom:52}}>
        <span className="derm">Derm</span><span className="diet">Diet</span>
      </div>
      <div style={{width:56,height:56,border:'3px solid var(--border)',borderTop:'3px solid var(--sage)',borderRadius:'50%',animation:'spin .9s linear infinite',marginBottom:36}}/>
      <div style={{textAlign:'center',minWidth:220}}>
        <div style={{fontSize:15,fontWeight:500,color:'var(--bark)',minHeight:24}}>{steps[step]}</div>
        <div style={{display:'flex',gap:6,justifyContent:'center',marginTop:20}}>
          {steps.map((_,i)=>(
            <div key={i} style={{
              height:6,borderRadius:3,
              background:i<=step?'var(--sage)':'var(--border)',
              width:i<=step?20:6,
              transition:'all .35s cubic-bezier(.4,0,.2,1)',
            }}/>
          ))}
        </div>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// RESULTS — OVERVIEW TAB
// ─────────────────────────────────────────────────────────────
function OverviewTab({ plan, profile, selectedDiets }) {
  return (
    <div style={{padding:'16px 20px',display:'flex',flexDirection:'column',gap:16}} className="anim-fade-up">
      <div className="dd-grad">
        <div style={{position:'relative',zIndex:1}}>
          <div style={{fontSize:22,fontWeight:700,marginBottom:4}}>{plan.name}</div>
          <div style={{fontSize:14,opacity:.85,marginBottom:18,fontStyle:'italic'}}>{plan.tagline}</div>
          <div style={{display:'flex',flexWrap:'wrap',gap:6}}>
            {[`📅 ${plan.duration}`,`🩺 ${profile.condition}`,...selectedDiets].map(t=>(
              <span key={t} style={{background:'rgba(255,255,255,.18)',borderRadius:20,padding:'4px 11px',fontSize:12,fontWeight:600}}>{t}</span>
            ))}
            {profile.budgetMode && (
              <span style={{background:'rgba(138,106,16,.45)',borderRadius:20,padding:'4px 11px',fontSize:12,fontWeight:600}}>💰 Budget Mode</span>
            )}
          </div>
        </div>
      </div>

      <div style={{background:'#FFFBF0',border:'1px solid #F0DDB0',borderRadius:12,padding:'12px 14px',fontSize:13,color:'#7A6510',display:'flex',gap:8,alignItems:'flex-start'}}>
        <span style={{flexShrink:0}}>⚠️</span>
        <span>This plan is <strong>not medical advice</strong>. Consult a dermatologist before making significant dietary changes.</span>
      </div>

      <div className="card">
        <p style={{fontSize:14,lineHeight:1.75,color:'var(--bark)'}}>{plan.summary}</p>
      </div>

      <div style={{background:'rgba(74,103,65,.07)',border:'1px solid rgba(74,103,65,.2)',borderRadius:12,padding:'14px 16px'}}>
        <div style={{fontSize:11,fontWeight:700,color:'var(--sage)',textTransform:'uppercase',letterSpacing:'.5px',marginBottom:6}}>🧴 Skin Focus</div>
        <p style={{fontSize:14,lineHeight:1.65,color:'var(--bark)'}}>{plan.skinFocus}</p>
      </div>

      {plan.alsoConsidered && profile.healthConditions.length>0 && (
        <div style={{background:'rgba(138,106,16,.07)',border:'1px solid rgba(138,106,16,.2)',borderRadius:12,padding:'14px 16px'}}>
          <div style={{fontSize:11,fontWeight:700,color:'var(--amber)',textTransform:'uppercase',letterSpacing:'.5px',marginBottom:6}}>⚠️ Also Considered</div>
          <p style={{fontSize:14,lineHeight:1.65,color:'var(--bark)'}}>{plan.alsoConsidered}</p>
        </div>
      )}

      {profile.budgetMode && (
        <div style={{background:'rgba(138,106,16,.06)',border:'1px solid rgba(138,106,16,.18)',borderRadius:12,padding:'14px 16px'}}>
          <div style={{fontSize:11,fontWeight:700,color:'var(--amber)',textTransform:'uppercase',letterSpacing:'.5px',marginBottom:6}}>💰 Budget Mode Active</div>
          <p style={{fontSize:14,lineHeight:1.65,color:'var(--bark)'}}>All meals use affordable staples: eggs, lentils, oats, canned fish, rice, frozen vegetables, and chicken thighs.</p>
        </div>
      )}

      {plan.principles?.length>0 && (
        <div className="card">
          <div style={{fontSize:14,fontWeight:700,marginBottom:14,color:'var(--bark)'}}>Core Principles</div>
          <div style={{display:'flex',flexDirection:'column',gap:10}}>
            {plan.principles.map((p,i)=>(
              <div key={i} style={{display:'flex',alignItems:'flex-start',gap:12}}>
                <div style={{width:26,height:26,background:'var(--sage)',borderRadius:8,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,color:'white',fontSize:12,fontWeight:700}}>
                  {i+1}
                </div>
                <span style={{fontSize:14,lineHeight:1.55,color:'var(--bark)',paddingTop:4}}>{p}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// RESULTS — TIMELINE TAB
// ─────────────────────────────────────────────────────────────
function TimelineTab({ plan }) {
  const alphas  = ['rgba(74,103,65,.08)','rgba(74,103,65,.12)','rgba(74,103,65,.18)']
  const borders = ['rgba(74,103,65,.2)', 'rgba(74,103,65,.3)', 'rgba(74,103,65,.4)' ]
  return (
    <div style={{padding:'16px 20px',display:'flex',flexDirection:'column',gap:14}} className="anim-fade-up">
      {plan.timeline?.map((phase,i)=>(
        <div key={i} style={{background:alphas[i]||alphas[2],border:`1.5px solid ${borders[i]||borders[2]}`,borderRadius:16,padding:'18px 20px'}}>
          <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:14}}>
            <div>
              <div style={{fontSize:16,fontWeight:700,color:'var(--bark)'}}>{phase.phase}</div>
              <div style={{fontSize:12,color:'var(--sage)',fontWeight:600,marginTop:3}}>{phase.weeks}</div>
            </div>
            <div style={{width:38,height:38,background:'var(--sage)',borderRadius:12,display:'flex',alignItems:'center',justifyContent:'center',color:'white',fontSize:17,fontWeight:700,flexShrink:0}}>
              {i+1}
            </div>
          </div>
          <div style={{display:'flex',flexDirection:'column',gap:9}}>
            {phase.actions?.map((action,j)=>(
              <div key={j} style={{display:'flex',gap:10,alignItems:'flex-start'}}>
                <div style={{width:6,height:6,borderRadius:'50%',background:'var(--sage)',marginTop:7,flexShrink:0}}/>
                <span style={{fontSize:13,lineHeight:1.55,color:'var(--bark)'}}>{action}</span>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// RESULTS — MEAL PLAN TAB
// ─────────────────────────────────────────────────────────────
function MealPlanTab({ plan, profile, selectedDiets, weeks, setWeeks }) {
  const [activeWeek,setActiveWeek] = useState(0)
  const [openDays,setOpenDays]     = useState({monday:true})
  const [swapModal,setSwapModal]   = useState(null)
  const [swapReason,setSwapReason] = useState('')
  const [swapAvoid,setSwapAvoid]   = useState('')
  const [swapping,setSwapping]     = useState(false)
  const [recipes,setRecipes]       = useState({})
  const [loadingRec,setLoadingRec] = useState({})
  const [generatingWeek,setGenW]   = useState(false)
  const [weekErr,setWeekErr]       = useState('')
  const [w1Swaps,setW1Swaps]       = useState({})

  const rKey = (wk,day,slot) => `${wk}-${day}-${slot}`

  function getDayData(wkIdx, day) {
    if (wkIdx===0) {
      const base = plan?.week1?.[day] || {}
      const ov   = w1Swaps?.[day] || {}
      return {...base,...ov}
    }
    return weeks[wkIdx-1]?.[day] || {}
  }

  async function fetchRecipe(wkIdx, day, slot) {
    const mealName = getDayData(wkIdx,day)[slot]
    const k = rKey(wkIdx,day,slot)
    if (recipes[k]) return
    setLoadingRec(r=>({...r,[k]:true}))
    try {
      const text = await callClaude(
        [{role:'user',content:`Full recipe for: "${mealName}". Return only JSON: {"ingredients":[{"item":"","amount":""}],"steps":["step"],"skinTip":"1 benefit sentence"}`}],
        `Dermatology nutritionist. ${profile.condition}, ${selectedDiets.join(' + ')} diet.`,
        400,
      )
      const parsed = repairJSON(text)
      setRecipes(r=>({...r,[k]:parsed||{error:'Could not parse recipe'}}))
    } catch(e) {
      setRecipes(r=>({...r,[k]:{error:e.message}}))
    } finally {
      setLoadingRec(r=>({...r,[k]:false}))
    }
  }

  function clearRecipe(wkIdx,day,slot) {
    const k=rKey(wkIdx,day,slot)
    setRecipes(r=>{const c={...r};delete c[k];return c})
  }

  async function doSwap() {
    if (!swapModal) return
    const {wkIdx,day,slot} = swapModal
    const mealName = getDayData(wkIdx,day)[slot]
    setSwapping(true)
    try {
      const text = await callClaude(
        [{role:'user',content:`Current meal: "${mealName}". Reason: "${swapReason}". Avoid: "${swapAvoid}". Reply with ONLY the replacement meal name (up to 60 chars).`}],
        `Dermatology nutritionist. ${profile.condition}. ${selectedDiets.join(' + ')}. ${profile.budgetMode?'Budget mode: eggs, lentils, oats, rice, frozen veg, canned fish, chicken thighs only.':''}`,
        60,
      )
      const newMeal = text.trim().replace(/^"|"$/g,'')
      if (wkIdx===0) {
        setW1Swaps(s=>({...s,[day]:{...s[day],[slot]:newMeal}}))
      } else {
        setWeeks(ws=>{
          const c=[...ws]
          c[wkIdx-1]={...c[wkIdx-1],[day]:{...c[wkIdx-1][day],[slot]:newMeal}}
          return c
        })
      }
      clearRecipe(wkIdx,day,slot)
      setSwapModal(null)
    } catch(e) {
      alert('Swap failed: '+e.message)
    } finally {
      setSwapping(false)
    }
  }

  async function generateNextWeek() {
    const nextNum = weeks.length+2
    setGenW(true); setWeekErr('')
    try {
      const prevMeals=[]
      if(plan?.week1) DAYS.forEach(d=>MEAL_SLOTS.forEach(s=>{ if(plan.week1[d]?.[s]) prevMeals.push(plan.week1[d][s]) }))
      weeks.forEach(w=>DAYS.forEach(d=>MEAL_SLOTS.forEach(s=>{ if(w[d]?.[s]) prevMeals.push(w[d][s]) })))
      const text = await callClaude(
        [{role:'user',content:`Generate Week ${nextNum} (progressively stricter than Week ${nextNum-1}). Avoid repeating: ${prevMeals.slice(0,20).join(', ')}. Return only JSON: {"monday":{"breakfast":"","lunch":"","dinner":"","snack":""},...all 7 days}`}],
        `Dermatology nutritionist. ${profile.condition}. ${selectedDiets.join(' + ')}. ${profile.budgetMode?'Budget mode only.':''} Return only compact JSON.`,
        700,
      )
      const parsed = repairJSON(text)
      if (!parsed) throw new Error('Could not parse week data')
      setWeeks(ws=>[...ws,parsed])
      setActiveWeek(weeks.length+1)
    } catch(e) {
      setWeekErr(e.message)
    } finally {
      setGenW(false)
    }
  }

  const REASONS = ["Don't like it","Missing ingredients","Want lighter","Want heavier","Tried it already","Want quicker"]

  return (
    <div style={{paddingBottom:24}}>
      <div className="week-tabs">
        <div className={`week-tab${activeWeek===0?' active':''}`} onClick={()=>setActiveWeek(0)}>Week 1</div>
        {weeks.map((_,i)=>(
          <div key={i+1} className={`week-tab${activeWeek===i+1?' active':''}`} onClick={()=>setActiveWeek(i+1)}>
            Week {i+2}
          </div>
        ))}
      </div>

      <div style={{padding:'12px 16px'}}>
        {DAYS.map(day=>{
          const isOpen  = openDays[day]
          const dayData = getDayData(activeWeek,day)
          return (
            <div key={day} className="dd-accordion">
              <div className={`dd-acc-hdr${isOpen?' open':''}`} onClick={()=>setOpenDays(d=>({...d,[day]:!isOpen}))}>
                <div style={{display:'flex',alignItems:'center',gap:10}}>
                  <span style={{fontSize:14,fontWeight:700,color:'var(--bark)'}}>{DAY_FULL[day]}</span>
                  {!isOpen && dayData?.breakfast && (
                    <span style={{fontSize:12,color:'var(--muted)',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap',maxWidth:160}}>
                      {dayData.breakfast}
                    </span>
                  )}
                </div>
                <span style={{color:'var(--muted)',fontSize:12,transition:'transform .3s',transform:isOpen?'rotate(180deg)':'none'}}>▾</span>
              </div>

              {isOpen && (
                <div style={{padding:'0 16px 10px'}}>
                  {MEAL_SLOTS.map(slot=>{
                    const meal = dayData?.[slot]||''
                    const k    = rKey(activeWeek,day,slot)
                    const rec  = recipes[k]
                    const ldg  = loadingRec[k]
                    return (
                      <div key={slot} style={{borderTop:'1px solid var(--border)',paddingTop:10,paddingBottom:10}}>
                        <div style={{display:'flex',alignItems:'center',gap:12}}>
                          <div style={{width:34,height:34,background:'rgba(74,103,65,.08)',borderRadius:10,display:'flex',alignItems:'center',justifyContent:'center',fontSize:17,flexShrink:0}}>
                            {MEAL_ICONS[slot]}
                          </div>
                          <div style={{flex:1,minWidth:0}}>
                            <div style={{fontSize:11,fontWeight:700,color:'var(--muted)',textTransform:'uppercase',letterSpacing:'.5px'}}>{slot}</div>
                            <div style={{fontSize:13,fontWeight:600,color:'var(--bark)',marginTop:2,lineHeight:1.35}}>{meal}</div>
                          </div>
                          <div style={{display:'flex',gap:6,flexShrink:0}}>
                            <button
                              onClick={()=>rec&&!rec.error?clearRecipe(activeWeek,day,slot):fetchRecipe(activeWeek,day,slot)}
                              style={{width:32,height:32,border:'1px solid var(--border)',borderRadius:8,background:rec&&!rec.error?'var(--sage)':'var(--card)',color:rec&&!rec.error?'white':'var(--muted)',cursor:'pointer',fontSize:14,display:'flex',alignItems:'center',justifyContent:'center'}}
                            >
                              📖
                            </button>
                            <button
                              onClick={()=>{setSwapModal({wkIdx:activeWeek,day,slot});setSwapReason('');setSwapAvoid('')}}
                              style={{width:32,height:32,border:'1px solid var(--border)',borderRadius:8,background:'var(--card)',color:'var(--muted)',cursor:'pointer',fontSize:14,display:'flex',alignItems:'center',justifyContent:'center'}}
                            >
                              🔄
                            </button>
                          </div>
                        </div>

                        {ldg && <Spinner size={20} pad={10}/>}
                        {rec && !rec.error && (
                          <div className="recipe-card">
                            <div style={{marginBottom:10}}>
                              <div style={{fontSize:11,fontWeight:700,color:'var(--sage)',marginBottom:6,textTransform:'uppercase'}}>Ingredients</div>
                              {rec.ingredients?.map((ing,i)=>(
                                <div key={i} style={{fontSize:12,display:'flex',gap:8,marginBottom:3}}>
                                  <span style={{color:'var(--muted)',minWidth:80,flexShrink:0}}>{ing.amount}</span>
                                  <span style={{color:'var(--bark)'}}>{ing.item}</span>
                                </div>
                              ))}
                            </div>
                            <div style={{marginBottom:10}}>
                              <div style={{fontSize:11,fontWeight:700,color:'var(--sage)',marginBottom:6,textTransform:'uppercase'}}>Method</div>
                              {rec.steps?.map((step,i)=>(
                                <div key={i} style={{fontSize:12,display:'flex',gap:8,marginBottom:4}}>
                                  <span style={{color:'var(--sage)',fontWeight:700,flexShrink:0}}>{i+1}.</span>
                                  <span style={{color:'var(--bark)',lineHeight:1.55}}>{step}</span>
                                </div>
                              ))}
                            </div>
                            {rec.skinTip && (
                              <div style={{background:'rgba(74,103,65,.1)',borderRadius:8,padding:'8px 10px',fontSize:12,color:'var(--sage)',fontWeight:500}}>
                                🧴 {rec.skinTip}
                              </div>
                            )}
                          </div>
                        )}
                        {rec?.error && (
                          <div style={{marginTop:8}}>
                            <ErrorMsg msg={rec.error} onRetry={()=>{clearRecipe(activeWeek,day,slot);fetchRecipe(activeWeek,day,slot)}}/>
                          </div>
                        )}
                      </div>
                    )
                  })}
                </div>
              )}
            </div>
          )
        })}

        <div style={{marginTop:16}}>
          {weekErr && <div style={{marginBottom:10}}><ErrorMsg msg={weekErr} onRetry={generateNextWeek}/></div>}
          <button className="btn-outline" style={{width:'100%'}} onClick={generateNextWeek} disabled={generatingWeek}>
            {generatingWeek ? <><Dots/>&nbsp;Generating Week {weeks.length+2}…</> : `+ Generate Week ${weeks.length+2}`}
          </button>
        </div>
      </div>

      {/* Swap modal */}
      {swapModal && (
        <div className="dd-overlay" onClick={e=>e.target===e.currentTarget&&setSwapModal(null)}>
          <div className="dd-sheet">
            <div className="dd-handle"/>
            <div style={{fontSize:17,fontWeight:700,marginBottom:4}}>Swap This Meal</div>
            <div style={{fontSize:13,color:'var(--muted)',marginBottom:20,fontStyle:'italic'}}>
              {getDayData(swapModal.wkIdx,swapModal.day)[swapModal.slot]}
            </div>
            <Label>Why are you swapping?</Label>
            <div style={{display:'flex',flexWrap:'wrap',gap:8,marginBottom:20}}>
              {REASONS.map(r=>(
                <button key={r} className={`swap-reason${swapReason===r?' sel':''}`} onClick={()=>setSwapReason(r)}>{r}</button>
              ))}
            </div>
            <Label>Ingredients to avoid?</Label>
            <input className="dd-input" placeholder="e.g. mushrooms, chickpeas…" value={swapAvoid} onChange={e=>setSwapAvoid(e.target.value)} style={{marginBottom:20}}/>
            <button className="btn-primary" style={{width:'100%'}} onClick={doSwap} disabled={swapping||!swapReason}>
              {swapping ? <><Dots/>&nbsp;Finding swap…</> : 'Find me a swap ✦'}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// RESULTS — FOODS TAB
// ─────────────────────────────────────────────────────────────
function FoodsTab({ plan, profile, selectedDiets }) {
  const [expanded,setExpanded] = useState(null)
  const [insights,setInsights] = useState({})
  const [loading,setLoading]   = useState({})

  async function fetchInsight(food) {
    if (expanded===food) { setExpanded(null); return }
    setExpanded(food)
    if (insights[food]) return
    setLoading(l=>({...l,[food]:true}))
    try {
      const text = await callClaude(
        [{role:'user',content:`In exactly 2 sentences, explain the biological mechanism by which "${food}" benefits ${profile.condition} skin. Name the specific nutrients, inflammatory pathways, or skin processes involved.`}],
        'You are a dermatology nutritionist explaining food science. Be precise and mechanistic.',
        120,
      )
      setInsights(i=>({...i,[food]:text.trim()}))
    } catch(e) {
      setInsights(i=>({...i,[food]:'Could not load insight.'}))
    } finally {
      setLoading(l=>({...l,[food]:false}))
    }
  }

  return (
    <div style={{padding:'16px 20px',display:'flex',flexDirection:'column',gap:16}} className="anim-fade-up">
      <p style={{fontSize:12,color:'var(--muted)',textAlign:'center'}}>
        Tap any 🟢 food to reveal the exact biological mechanism
      </p>
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:12,alignItems:'start'}}>
        <div className="card" style={{padding:0}}>
          <div style={{padding:'14px 16px 10px',borderBottom:'1px solid var(--border)'}}>
            <div style={{fontSize:13,fontWeight:700,color:'var(--sage)'}}>🟢 Eat These</div>
          </div>
          <div style={{padding:'6px 8px'}}>
            {plan.eatFoods?.map((item,i)=>(
              <div key={i}>
                <div className={`food-item${expanded===item.food?' open':''}`} onClick={()=>fetchInsight(item.food)}>
                  <div style={{flex:1,minWidth:0}}>
                    <div style={{fontSize:13,fontWeight:600,color:'var(--bark)'}}>{item.food}</div>
                    <div style={{fontSize:11,color:'var(--muted)',marginTop:2,lineHeight:1.35}}>{item.reason}</div>
                  </div>
                  <span style={{fontSize:10,color:'var(--sage)',flexShrink:0,marginTop:2}}>
                    {expanded===item.food?'▲':'▼'}
                  </span>
                </div>
                {expanded===item.food && (
                  <div style={{margin:'0 8px 8px',padding:'10px 12px',background:'rgba(74,103,65,.07)',borderRadius:8,fontSize:12,lineHeight:1.65,color:'var(--bark)'}} className="anim-fade-in">
                    {loading[item.food] ? <Dots color="var(--sage)"/> : insights[item.food]}
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>

        <div className="card" style={{padding:0}}>
          <div style={{padding:'14px 16px 10px',borderBottom:'1px solid var(--border)'}}>
            <div style={{fontSize:13,fontWeight:700,color:'#B94040'}}>🔴 Avoid These</div>
          </div>
          <div style={{padding:'6px 8px'}}>
            {plan.avoidFoods?.map((item,i)=>(
              <div key={i} className="food-item" style={{cursor:'default'}}>
                <div>
                  <div style={{fontSize:13,fontWeight:600,color:'var(--bark)'}}>{item.food}</div>
                  <div style={{fontSize:11,color:'var(--muted)',marginTop:2,lineHeight:1.35}}>{item.reason}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// RESULTS — GROCERY TAB
// ─────────────────────────────────────────────────────────────
function GroceryTab({ plan, profile, selectedDiets }) {
  const [data,setData]    = useState(null)
  const [loading,setLoad] = useState(false)
  const [err,setErr]      = useState('')

  const doFetch = useCallback(async () => {
    setLoad(true); setErr('')
    try {
      const meals=[]
      if(plan?.week1) DAYS.forEach(d=>MEAL_SLOTS.forEach(s=>{ if(plan.week1[d]?.[s]) meals.push(plan.week1[d][s]) }))
      const eats = plan?.eatFoods?.map(f=>f.food).join(', ')||''
      const text = await callClaude(
        [{role:'user',content:`Grocery list for: ${meals.slice(0,14).join(', ')}. Also include: ${eats}. ${profile.budgetMode?'Budget mode — add (bulk) tag to bulk items.':''} Return only JSON: {"Produce":[],"Proteins":[],"Grains & Carbs":[],"Dairy & Alternatives":[],"Pantry":[],"Other":[]}`}],
        'You are a grocery list organizer for a dermatology nutrition plan. Return only compact JSON.',
        500,
      )
      const parsed = repairJSON(text)
      if (!parsed) throw new Error('Could not parse grocery list')
      setData(parsed)
    } catch(e) {
      setErr(e.message)
    } finally {
      setLoad(false)
    }
  },[plan,profile])

  useEffect(()=>{ if(!data&&!loading) doFetch() },[])

  if (loading) return <Spinner/>
  if (err)     return <div style={{padding:20}}><ErrorMsg msg={err} onRetry={doFetch}/></div>
  if (!data)   return null

  return (
    <div style={{padding:'16px 20px',display:'flex',flexDirection:'column',gap:20}} className="anim-fade-up">
      {GROCERY_GROUPS.map(group=>{
        const items = data[group]
        if (!items?.length) return null
        return (
          <div key={group}>
            <div style={{fontSize:12,fontWeight:700,color:'var(--muted)',textTransform:'uppercase',letterSpacing:'.6px',marginBottom:8}}>
              {group}
            </div>
            <div style={{display:'flex',flexWrap:'wrap'}}>
              {items.map((item,i)=>(
                <span key={i} className="grocery-chip">{item}</span>
              ))}
            </div>
          </div>
        )
      })}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// RESULTS — ASK AI TAB
// ─────────────────────────────────────────────────────────────
function ChatTab({ plan, profile, selectedDiets }) {
  const [messages,setMessages] = useState([])
  const [input,setInput]       = useState('')
  const [loading,setLoading]   = useState(false)
  const endRef                 = useRef(null)

  const SUGGESTIONS = [
    { icon:'🔄', text:"Swap Monday's lunch for me"          },
    { icon:'🍽️', text:"What can I eat at a restaurant?"    },
    { icon:'⚡',  text:"Quick snack ideas for my skin"       },
    { icon:'🥛', text:"Why should I avoid dairy?"           },
    { icon:'🌙', text:"I'm still hungry after dinner — help"},
  ]

  const meals=[]
  if(plan?.week1) DAYS.forEach(d=>MEAL_SLOTS.forEach(s=>{ if(plan.week1[d]?.[s]) meals.push(plan.week1[d][s]) }))

  const sysPrompt = `You are a warm, knowledgeable dermatology nutritionist who knows this user's plan intimately.
Condition: ${profile.condition}. Age: ${profile.age}. Sex: ${profile.sex}.
Diet: ${selectedDiets.join(' + ')}.${profile.budgetMode?' Budget mode active.':''}
${profile.allergies.length?`Allergies: ${profile.allergies.join(', ')}.`:''}
${profile.healthConditions.length?`Health considerations: ${profile.healthConditions.join(', ')}.`:''}
Principles: ${plan?.principles?.join('; ')}.
Week 1 meals (sample): ${meals.slice(0,8).join(', ')}.
Eat: ${plan?.eatFoods?.map(f=>f.food).join(', ')}.
Avoid: ${plan?.avoidFoods?.map(f=>f.food).join(', ')}.
Always tie advice back to the user's specific skin condition. Be concise and actionable.`

  async function send(text) {
    const msg = text || input.trim()
    if (!msg) return
    setInput('')
    const updated = [...messages, {role:'user',content:msg}]
    setMessages(updated)
    setLoading(true)
    try {
      const reply = await callClaude(
        updated.map(m=>({role:m.role,content:m.content})),
        sysPrompt,
        500,
      )
      setMessages(m=>[...m,{role:'assistant',content:reply}])
    } catch(e) {
      setMessages(m=>[...m,{role:'assistant',content:`Sorry, I hit an error: ${e.message}`}])
    } finally {
      setLoading(false)
    }
  }

  useEffect(()=>{ endRef.current?.scrollIntoView({behavior:'smooth'}) },[messages,loading])

  return (
    <div style={{display:'flex',flexDirection:'column',height:'calc(100vh - 200px)'}}>
      <div style={{flex:1,overflowY:'auto',padding:'16px 20px',display:'flex',flexDirection:'column',gap:12}}>
        {messages.length===0 && (
          <div style={{textAlign:'center',paddingTop:24}}>
            <div style={{fontSize:40,marginBottom:10}}>🤖</div>
            <div style={{fontSize:15,fontWeight:700,color:'var(--bark)',marginBottom:4}}>Your AI Nutritionist</div>
            <div style={{fontSize:13,color:'var(--muted)',marginBottom:24}}>Ask me anything about your skin diet plan</div>
            <div style={{display:'flex',flexDirection:'column',gap:8}}>
              {SUGGESTIONS.map((s,i)=>(
                <button key={i} onClick={()=>send(s.text)} style={{
                  textAlign:'left',padding:'11px 16px',background:'var(--card)',
                  border:'1px solid var(--border)',borderRadius:12,
                  fontFamily:"'DM Sans',sans-serif",fontSize:13,fontWeight:500,color:'var(--bark)',
                  cursor:'pointer',display:'flex',alignItems:'center',gap:10,transition:'all .15s',
                }}>
                  <span>{s.icon}</span>{s.text}
                </button>
              ))}
            </div>
          </div>
        )}
        {messages.map((m,i)=>(
          <div key={i} style={{display:'flex',justifyContent:m.role==='user'?'flex-end':'flex-start'}}>
            <div className={`dd-bubble ${m.role==='user'?'user':'ai'}`}>{m.content}</div>
          </div>
        ))}
        {loading && (
          <div style={{display:'flex'}}>
            <div className="dd-bubble ai"><Dots color="var(--sage)"/></div>
          </div>
        )}
        <div ref={endRef}/>
      </div>

      <div style={{padding:'12px 20px',borderTop:'1px solid var(--border)',background:'var(--card)',display:'flex',gap:10}}>
        <input className="dd-input" placeholder="Ask about your plan…" value={input}
          onChange={e=>setInput(e.target.value)}
          onKeyDown={e=>e.key==='Enter'&&!e.shiftKey&&send()}
          style={{flex:1}}/>
        <button className="btn-primary" onClick={()=>send()} disabled={loading||!input.trim()} style={{padding:'12px 16px',flexShrink:0}}>
          ↑
        </button>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// RESULTS SCREEN
// ─────────────────────────────────────────────────────────────
const TABS = [
  { id:'overview', label:'✦ Overview' },
  { id:'timeline', label:'📅 Timeline' },
  { id:'meals',    label:'🍽 Meal Plan'},
  { id:'foods',    label:'🥗 Foods'   },
  { id:'grocery',  label:'🛒 Grocery' },
  { id:'chat',     label:'🤖 Ask AI'  },
]

function ResultsScreen({ plan, profile, selectedDiets }) {
  const [activeTab,setActiveTab] = useState('overview')
  const [weeks,setWeeks]         = useState([])

  return (
    <div className="screen">
      <div style={{background:'var(--card)',borderBottom:'1px solid var(--border)',paddingTop:52}}>
        <div style={{padding:'0 20px',display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:12}}>
          <div className="dd-wordmark" style={{fontSize:22}}>
            <span className="derm">Derm</span><span className="diet">Diet</span>
          </div>
          <div style={{fontSize:12,color:'var(--muted)',textAlign:'right'}}>
            {profile.condition}<br/>{selectedDiets[0]}
          </div>
        </div>
        <div className="dd-tabbar">
          {TABS.map(t=>(
            <div key={t.id} className={`dd-tab${activeTab===t.id?' active':''}`} onClick={()=>setActiveTab(t.id)}>
              {t.label}
            </div>
          ))}
        </div>
      </div>

      <div className="pb-safe">
        {activeTab==='overview' && <OverviewTab plan={plan} profile={profile} selectedDiets={selectedDiets}/>}
        {activeTab==='timeline' && <TimelineTab plan={plan}/>}
        {activeTab==='meals'    && <MealPlanTab plan={plan} profile={profile} selectedDiets={selectedDiets} weeks={weeks} setWeeks={setWeeks}/>}
        {activeTab==='foods'    && <FoodsTab    plan={plan} profile={profile} selectedDiets={selectedDiets}/>}
        {activeTab==='grocery'  && <GroceryTab  plan={plan} profile={profile} selectedDiets={selectedDiets}/>}
        {activeTab==='chat'     && <ChatTab     plan={plan} profile={profile} selectedDiets={selectedDiets}/>}
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// ROOT APP
// ─────────────────────────────────────────────────────────────
export default function App() {
  const [screen,setScreen]               = useState('welcome')
  const [profile,setProfile]             = useState({
    condition:'', conditionOther:'',
    age:'', sex:'',
    budgetMode:false,
    allergies:[], otherAllergies:[],
    healthConditions:[], otherHealth:[],
  })
  const [selectedDiets,setSelectedDiets] = useState([])
  const [plan,setPlan]                   = useState(null)
  const [generating,setGenerating]       = useState(false)
  const [genError,setGenError]           = useState('')

  async function generatePlan() {
    setGenerating(true); setGenError(''); setScreen('loading')
    try {
      const text = await callClaude(
        [{role:'user',content:buildPlanPrompt(profile,selectedDiets)}],
        buildSystemPrompt(profile,selectedDiets),
        1600,
      )
      const parsed = repairJSON(text)
      if (!parsed?.week1) throw new Error('Invalid plan returned — please try again.')
      setPlan(parsed)
      setScreen('results')
    } catch(e) {
      setGenError(e.message)
      setScreen('diet')
    } finally {
      setGenerating(false)
    }
  }

  return (
    <div style={{background:'var(--cream)',minHeight:'100vh'}}>
      {screen==='welcome' && <WelcomeScreen onStart={()=>setScreen('profile')}/>}
      {screen==='profile' && <ProfileScreen profile={profile} setProfile={setProfile} onNext={()=>setScreen('diet')}/>}
      {screen==='diet'    && (
        <DietScreen
          profile={profile}
          selectedDiets={selectedDiets}
          setSelectedDiets={setSelectedDiets}
          onGenerate={generatePlan}
          generating={generating}
          genError={genError}
        />
      )}
      {screen==='loading' && <LoadingScreen profile={profile} selectedDiets={selectedDiets}/>}
      {screen==='results' && plan && <ResultsScreen plan={plan} profile={profile} selectedDiets={selectedDiets}/>}
    </div>
  )
}
