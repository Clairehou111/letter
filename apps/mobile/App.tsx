import { useEffect, useRef, useState, useCallback } from 'react'

// ─── Design tokens ────────────────────────────────────────────────────────────
const C = {
  canvas:      '#0B0C10',
  curveTeal:   '#4ECDC4',
  curveIndigo: '#6B8FA3',
  curveViolet: '#3D2B4F',
  dotCore:     '#D4EDE8',
  dotGlow:     '#8BE0D0',
  textDim:     '#3A3D4A',
  textFaint:   '#252830',
  textVfaint:  '#1A1D25',
  surface:     '#111318',
  surfaceHi:   '#161920',
  rage:        { inner: '#C41E3A', outer: '#7B0D2A' },
  anxiety:     { inner: '#5533AA', outer: '#2D1B5E' },
  tears:       { inner: '#8B4870', outer: '#4A2040' },
  fatigue:     { inner: '#1A4A5E', outer: '#0D2535' },
}

// ─── Shared helpers ───────────────────────────────────────────────────────────
function easeInOut(t: number) { return t < 0.5 ? 2*t*t : -1+(4-2*t)*t }
function lerp(a: number, b: number, t: number) { return a + (b-a)*t }
function hexToRgb(hex: string): [number,number,number] {
  const n = parseInt(hex.slice(1), 16)
  return [(n>>16)&255, (n>>8)&255, n&255]
}
function rgba(hex: string, a: number) {
  const [r,g,b] = hexToRgb(hex)
  return `rgba(${r},${g},${b},${a})`
}
function useAnimationFrame(cb: (t: number) => void) {
  const ref = useRef<number>(0)
  const start = useRef<number|null>(null)
  useEffect(() => {
    const loop = (ts: number) => {
      if (!start.current) start.current = ts
      cb((ts - start.current) / 1000)
      ref.current = requestAnimationFrame(loop)
    }
    ref.current = requestAnimationFrame(loop)
    return () => cancelAnimationFrame(ref.current)
  }, [cb])
}

// ─── Mock cycle data ──────────────────────────────────────────────────────────
interface PatternIntensity {
  dayOffset: number; rage: number; fatigue: number; anxiety: number; tearfulness: number
}
interface CycleViewState {
  currentCycleDay: number; predictedLutealStart: number; cycleLength: number
  patternData: PatternIntensity[]; tideCopy: string
}
const MOCK_STATE: CycleViewState = {
  currentCycleDay: 19, predictedLutealStart: 15, cycleLength: 28,
  tideCopy: 'current tide: entering the luteal valley. gravity feels heavier today. you are safe to slow down.',
  patternData: [
    {dayOffset:-14,rage:0.00,fatigue:0.20,anxiety:0.00,tearfulness:0.00},
    {dayOffset:-13,rage:0.00,fatigue:0.25,anxiety:0.10,tearfulness:0.00},
    {dayOffset:-12,rage:0.00,fatigue:0.30,anxiety:0.15,tearfulness:0.00},
    {dayOffset:-11,rage:0.00,fatigue:0.35,anxiety:0.20,tearfulness:0.00},
    {dayOffset:-10,rage:0.10,fatigue:0.40,anxiety:0.25,tearfulness:0.00},
    {dayOffset: -9,rage:0.15,fatigue:0.45,anxiety:0.30,tearfulness:0.00},
    {dayOffset: -8,rage:0.20,fatigue:0.50,anxiety:0.40,tearfulness:0.20},
    {dayOffset: -7,rage:0.30,fatigue:0.55,anxiety:0.50,tearfulness:0.30},
    {dayOffset: -6,rage:0.40,fatigue:0.60,anxiety:0.55,tearfulness:0.35},
    {dayOffset: -5,rage:0.55,fatigue:0.65,anxiety:0.60,tearfulness:0.45},
    {dayOffset: -4,rage:0.70,fatigue:0.70,anxiety:0.65,tearfulness:0.55},
    {dayOffset: -3,rage:0.92,fatigue:0.60,anxiety:0.70,tearfulness:0.70},
    {dayOffset: -2,rage:0.75,fatigue:0.50,anxiety:0.60,tearfulness:0.80},
    {dayOffset: -1,rage:0.50,fatigue:0.40,anxiety:0.50,tearfulness:0.65},
  ],
}

// ─── Gravity Horizon (Today) ──────────────────────────────────────────────────
function GravityHorizon({ state }: { state: CycleViewState }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const wrapRef = useRef<HTMLDivElement>(null)

  const draw = useCallback((t: number) => {
    const canvas = canvasRef.current; if (!canvas) return
    const ctx = canvas.getContext('2d')!
    const W = canvas.width, H = canvas.height
    ctx.clearRect(0, 0, W, H)
    const bandTop = H*0.62, bandBot = H*0.88, bandH = bandBot-bandTop
    const restY = bandTop + bandH*0.25, valleyY = bandTop + bandH*0.78
    const breathe = Math.sin(t*Math.PI*2/6)*2.5
    const lutealX = (state.predictedLutealStart-1)/state.cycleLength
    const path = new Path2D()
    path.moveTo(0, restY+breathe)
    if (state.currentCycleDay >= state.predictedLutealStart) {
      path.bezierCurveTo(W*lutealX,restY+breathe,W*(lutealX+0.35),valleyY+breathe,W,valleyY+breathe)
    } else {
      const ix = W*(lutealX*0.88)
      path.bezierCurveTo(W*0.30,restY-5+breathe,ix,restY+breathe,W*lutealX,restY+breathe)
      path.bezierCurveTo(W*(lutealX+0.08),valleyY*0.55+restY*0.45+breathe,W*(lutealX+0.16),valleyY+breathe,W,valleyY+breathe)
    }
    for (const g of [{w:22,a:0.03},{w:14,a:0.055},{w:8,a:0.10},{w:3.5,a:0.18}]) {
      ctx.save(); ctx.strokeStyle=rgba(C.dotGlow,g.a); ctx.lineWidth=g.w
      ctx.lineCap='round'; ctx.filter='blur(6px)'; ctx.stroke(path); ctx.restore()
    }
    const grad = ctx.createLinearGradient(0,0,W,0)
    grad.addColorStop(0.00,rgba(C.curveTeal,0.90))
    grad.addColorStop(0.50,rgba(C.curveIndigo,0.65))
    grad.addColorStop(1.00,rgba(C.curveViolet,0.80))
    ctx.save(); ctx.strokeStyle=grad; ctx.lineWidth=0.85; ctx.lineCap='round'; ctx.stroke(path); ctx.restore()
    const tx = state.currentCycleDay/state.cycleLength
    const dotX = W*tx
    const dotY = tx<=lutealX ? restY+breathe : lerp(restY,valleyY,easeInOut((tx-lutealX)/(1-lutealX)))+breathe
    const hp = 6+Math.sin(t*Math.PI*2/6)*2.5
    ctx.save(); ctx.beginPath(); ctx.arc(dotX,dotY,hp*2.2,0,Math.PI*2)
    ctx.fillStyle=rgba(C.dotGlow,0.12); ctx.filter=`blur(${hp}px)`; ctx.fill(); ctx.restore()
    ctx.save(); ctx.beginPath(); ctx.arc(dotX,dotY,7,0,Math.PI*2)
    ctx.fillStyle=rgba(C.dotGlow,0.30); ctx.filter='blur(4px)'; ctx.fill(); ctx.restore()
    ctx.save(); ctx.beginPath(); ctx.arc(dotX,dotY,2.8,0,Math.PI*2)
    ctx.fillStyle=C.dotCore; ctx.fill(); ctx.restore()
  }, [state])

  useAnimationFrame(draw)
  useEffect(() => {
    const canvas = canvasRef.current, wrap = wrapRef.current; if (!canvas||!wrap) return
    const ro = new ResizeObserver(() => { canvas.width=wrap.clientWidth; canvas.height=wrap.clientHeight })
    ro.observe(wrap); canvas.width=wrap.clientWidth; canvas.height=wrap.clientHeight
    return () => ro.disconnect()
  }, [])

  const phase = state.currentCycleDay >= state.predictedLutealStart ? 'luteal'
    : state.currentCycleDay <= 5 ? 'menstrual' : 'follicular'
  const font = "'Cormorant Garamond', Georgia, serif"

  return (
    <div ref={wrapRef} style={{position:'relative',width:'100%',height:'100%',background:C.canvas}}>
      <div style={{position:'absolute',top:36,left:28,right:28,display:'flex',justifyContent:'space-between',alignItems:'flex-start'}}>
        <div>
          <div style={{fontFamily:font,fontWeight:200,fontSize:11,letterSpacing:'2px',color:C.textFaint,textTransform:'lowercase'}}>cycle day</div>
          <div style={{fontFamily:font,fontWeight:200,fontSize:52,letterSpacing:'-1px',lineHeight:1,color:C.textVfaint}}>{state.currentCycleDay}</div>
        </div>
        <div style={{textAlign:'right'}}>
          <div style={{fontFamily:font,fontWeight:200,fontSize:11,letterSpacing:'2px',color:C.textFaint,textTransform:'lowercase'}}>phase</div>
          <div style={{fontFamily:font,fontWeight:300,fontSize:13,letterSpacing:'0.8px',color:C.textDim,textTransform:'lowercase',marginTop:4}}>{phase}</div>
        </div>
      </div>
      <canvas ref={canvasRef} style={{position:'absolute',inset:0,width:'100%',height:'100%'}} />
      <div style={{position:'absolute',bottom:28,left:28,right:28,fontFamily:font,fontWeight:200,fontSize:12,lineHeight:1.85,letterSpacing:'0.7px',color:C.textFaint,textTransform:'lowercase'}}>
        {state.tideCopy}
      </div>
    </div>
  )
}

// ─── Spectrum Log (Patterns) ──────────────────────────────────────────────────
function SpectrumLog({ state }: { state: CycleViewState }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const wrapRef = useRef<HTMLDivElement>(null)
  const draw = useCallback((t: number) => {
    const canvas = canvasRef.current; if (!canvas) return
    const ctx = canvas.getContext('2d')!
    const W = canvas.width, H = canvas.height
    ctx.clearRect(0,0,W,H)
    const baseGrad = ctx.createLinearGradient(0,0,W,0)
    baseGrad.addColorStop(0,'#0F1015'); baseGrad.addColorStop(0.5,'#131620'); baseGrad.addColorStop(1,'#0F1015')
    ctx.fillStyle=baseGrad; ctx.beginPath(); ctx.roundRect(0,0,W,H,4); ctx.fill()
    const dayToX = (d:number) => ((d+14)/13)*W
    const sigs = [
      {key:'rage' as const,   inner:C.rage.inner,   outer:C.rage.outer,   rm:1.15},
      {key:'anxiety' as const,inner:C.anxiety.inner,outer:C.anxiety.outer,rm:0.90},
      {key:'tearfulness' as const,inner:C.tears.inner,outer:C.tears.outer,rm:0.85},
      {key:'fatigue' as const,inner:C.fatigue.inner,outer:C.fatigue.outer,rm:0.75},
    ]
    ctx.save(); ctx.beginPath(); ctx.roundRect(0,0,W,H,4); ctx.clip()
    for (const pat of state.patternData) {
      const xC = dayToX(pat.dayOffset)
      const ph = (pat.dayOffset/-14)*Math.PI+(t*Math.PI*2/8)
      const pulse = 1+Math.sin(ph)*0.06
      for (const sig of sigs) {
        const intensity = pat[sig.key]; if (intensity<0.04) continue
        const radius = H*2.4*intensity*sig.rm*pulse
        const yC = H*0.5
        const grd = ctx.createRadialGradient(xC,yC,0,xC,yC,radius)
        const [ri,gi,bi]=hexToRgb(sig.inner); const [ro,go,bo]=hexToRgb(sig.outer)
        grd.addColorStop(0,`rgba(${ri},${gi},${bi},${intensity*0.80})`)
        grd.addColorStop(0.50,`rgba(${ro},${go},${bo},${intensity*0.35})`)
        grd.addColorStop(1,`rgba(${ro},${go},${bo},0)`)
        ctx.save(); ctx.filter=`blur(${Math.max(4,radius*0.42)}px)`
        ctx.beginPath(); ctx.arc(xC,yC,radius,0,Math.PI*2); ctx.fillStyle=grd; ctx.fill(); ctx.restore()
      }
    }
    ctx.restore()
    const daysUntilBleed = state.cycleLength-state.currentCycleDay
    const todayOffset = -(daysUntilBleed+1)
    if (todayOffset>=-14&&todayOffset<=-1&&state.currentCycleDay>=state.predictedLutealStart) {
      const tx=dayToX(todayOffset); const br=Math.sin(t*Math.PI*2/6)*1.5
      ctx.save(); ctx.strokeStyle=rgba(C.dotCore,0.50); ctx.lineWidth=0.6
      ctx.beginPath(); ctx.moveTo(tx,0); ctx.lineTo(tx,H); ctx.stroke(); ctx.restore()
      ctx.save(); ctx.beginPath(); ctx.arc(tx,H*0.5+br,7,0,Math.PI*2)
      ctx.fillStyle=rgba(C.dotGlow,0.20); ctx.filter='blur(5px)'; ctx.fill(); ctx.restore()
      ctx.save(); ctx.beginPath(); ctx.arc(tx,H*0.5+br,2.2,0,Math.PI*2)
      ctx.fillStyle=C.dotCore; ctx.fill(); ctx.restore()
    }
    ctx.save(); ctx.strokeStyle=rgba('#2A2D38',1); ctx.lineWidth=0.5
    for (let d=-14;d<=-1;d++) { const x=dayToX(d); ctx.beginPath(); ctx.moveTo(x,H-4); ctx.lineTo(x,H); ctx.stroke() }
    ctx.restore()
  }, [state])
  useAnimationFrame(draw)
  useEffect(() => {
    const canvas=canvasRef.current,wrap=wrapRef.current; if (!canvas||!wrap) return
    const ro=new ResizeObserver(()=>{canvas.width=wrap.clientWidth;canvas.height=wrap.clientHeight})
    ro.observe(wrap); canvas.width=wrap.clientWidth; canvas.height=wrap.clientHeight
    return ()=>ro.disconnect()
  }, [])
  const peakRage = state.patternData.reduce((a,b)=>a.rage>b.rage?a:b)
  const bodyNote = peakRage.rage>0.3
    ? `your body tends to concentrate high-intensity energy around day ${peakRage.dayOffset}. this is not a flaw. this is data. rest is a valid response.`
    : null
  const font = "'Cormorant Garamond', Georgia, serif"
  const lbl: React.CSSProperties = {fontFamily:font,fontWeight:200,fontSize:11,letterSpacing:'1.8px',color:C.textFaint,textTransform:'lowercase'}
  return (
    <div style={{padding:'48px 28px',background:C.canvas,minHeight:'100%'}}>
      <div style={{marginBottom:48}}>
        <div style={{fontFamily:font,fontWeight:200,fontSize:30,letterSpacing:'-0.3px',lineHeight:1.1,color:C.textVfaint,textTransform:'lowercase'}}>your patterns</div>
        <div style={{...lbl,marginTop:6}}>learned from your own history</div>
      </div>
      <div style={{...lbl,marginBottom:16}}>hormonal spectrum · luteal phase</div>
      <div ref={wrapRef} style={{width:'100%',height:60,position:'relative'}}>
        <canvas ref={canvasRef} style={{position:'absolute',inset:0,width:'100%',height:'100%'}} />
      </div>
      <div style={{display:'flex',justifyContent:'space-between',marginTop:10,...lbl,fontSize:9,letterSpacing:'0.6px'}}>
        <span>day −14</span><span>day −1</span>
      </div>
      <div style={{display:'flex',flexWrap:'wrap',gap:'8px 20px',marginTop:28}}>
        {[{color:C.rage.outer,label:'rage · irritability'},{color:C.anxiety.outer,label:'anxiety · dread'},
          {color:C.tears.outer,label:'tearfulness'},{color:C.fatigue.inner,label:'fatigue'}].map(s=>(
          <div key={s.label} style={{display:'flex',alignItems:'center',gap:7}}>
            <div style={{width:6,height:6,borderRadius:'50%',background:s.color,boxShadow:`0 0 5px 1px ${s.color}`}} />
            <span style={{...lbl,fontSize:10,letterSpacing:'0.5px',color:C.textDim}}>{s.label}</span>
          </div>
        ))}
      </div>
      {bodyNote && <div style={{marginTop:48,fontFamily:font,fontWeight:200,fontSize:12,lineHeight:1.95,letterSpacing:'0.6px',color:C.textFaint,textTransform:'lowercase',maxWidth:400}}>{bodyNote}</div>}
    </div>
  )
}

// ─── Symptom Logger ───────────────────────────────────────────────────────────

const INTENSITY_WORDS = ['barely','mild','moderate','strong','severe','overwhelming'] as const
type IntensityWord = typeof INTENSITY_WORDS[number]

const INTENSITY_GLOW: Record<IntensityWord, number> = {
  barely: 0.12, mild: 0.22, moderate: 0.38, strong: 0.55, severe: 0.72, overwhelming: 0.92
}

interface Symptom {
  id: string
  label: string
  icon: string
  color: string   // glow accent
}

const SYMPTOMS: Symptom[] = [
  {id:'cramps',      label:'cramps',        icon:'◎',  color:'#C41E3A'},
  {id:'headache',    label:'headache',      icon:'⊙',  color:'#8B4870'},
  {id:'breast',      label:'breast tender', icon:'◌',  color:'#8B4870'},
  {id:'bloating',    label:'bloating',      icon:'○',  color:'#5533AA'},
  {id:'nausea',      label:'nausea',        icon:'≈',  color:'#5533AA'},
  {id:'bodyache',    label:'body aches',    icon:'⋯',  color:'#7B0D2A'},
  {id:'lowenergy',   label:'low energy',    icon:'◡',  color:'#1A4A5E'},
  {id:'irritable',   label:'irritability',  icon:'∿',  color:'#C41E3A'},
  {id:'anxiety',     label:'anxiety',       icon:'∾',  color:'#5533AA'},
  {id:'brain',       label:'brain fog',     icon:'◈',  color:'#2D1B5E'},
  {id:'lowmood',     label:'low mood',      icon:'◠',  color:'#4A2040'},
  {id:'insomnia',    label:'insomnia',      icon:'◑',  color:'#2D1B5E'},
  {id:'sleepy',      label:'sleepiness',    icon:'◐',  color:'#0D2535'},
  {id:'rage',        label:'rage',          icon:'⊗',  color:'#7B0D2A'},
  {id:'tears',       label:'tearfulness',   icon:'◟',  color:'#4A2040'},
  {id:'sensitive',   label:'sensitivity',   icon:'◜',  color:'#8B4870'},
]

interface SymptomEntry {
  symptomId: string
  intensity: IntensityWord | null
}

function SymptomLogger() {
  const [entries, setEntries] = useState<Record<string, SymptomEntry>>({})
  const [activeId, setActiveId] = useState<string|null>(null)
  const font = "'Cormorant Garamond', Georgia, serif"

  const selectedIds = Object.keys(entries)
  const saveCount = selectedIds.filter(id => entries[id].intensity !== null).length

  function toggleSymptom(id: string) {
    if (entries[id]) {
      // already selected — just focus it for intensity pick
      setActiveId(id)
    } else {
      setEntries(prev => ({...prev, [id]: {symptomId:id, intensity:null}}))
      setActiveId(id)
    }
  }

  function clearSymptom(id: string) {
    setEntries(prev => { const n={...prev}; delete n[id]; return n })
    if (activeId===id) setActiveId(null)
  }

  function setIntensity(id: string, word: IntensityWord) {
    setEntries(prev => ({...prev, [id]: {symptomId:id, intensity:word}}))
  }

  const lbl: React.CSSProperties = {
    fontFamily:font, fontWeight:200, fontSize:10,
    letterSpacing:'1.6px', textTransform:'lowercase', color:C.textFaint,
  }

  return (
    <div style={{background:C.canvas,minHeight:'100%',paddingBottom:100,overflowY:'auto'}}>
      {/* Header */}
      <div style={{padding:'42px 24px 24px'}}>
        <div style={{fontFamily:font,fontWeight:200,fontSize:26,color:'#3A4055',textTransform:'lowercase',letterSpacing:'-0.2px',lineHeight:1.1}}>how are you feeling?</div>
        <div style={{...lbl,marginTop:6,color:C.textFaint}}>tap to select · tap again to adjust</div>
      </div>

      {/* Symptom grid */}
      <div style={{padding:'0 20px',display:'flex',flexWrap:'wrap',gap:10}}>
        {SYMPTOMS.map(sym => {
          const entry = entries[sym.id]
          const isSelected = !!entry
          const isActive = activeId === sym.id
          const intensity = entry?.intensity ?? null
          const glowAlpha = intensity ? INTENSITY_GLOW[intensity] : 0
          const glowColor = sym.color

          return (
            <div key={sym.id} style={{position:'relative'}}>
              <button
                onClick={() => toggleSymptom(sym.id)}
                style={{
                  position:'relative',
                  display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center',
                  gap:5, padding:'14px 18px',
                  background: isSelected ? rgba(glowColor, 0.08) : C.surface,
                  border: isActive
                    ? `1px solid ${rgba(glowColor, 0.55)}`
                    : isSelected
                    ? `1px solid ${rgba(glowColor, 0.25)}`
                    : `1px solid ${rgba('#ffffff', 0.04)}`,
                  borderRadius:12,
                  cursor:'pointer',
                  minWidth:80,
                  boxShadow: isSelected
                    ? `0 0 ${12 + glowAlpha*24}px ${rgba(glowColor, glowAlpha * 0.7)}, inset 0 0 ${8 + glowAlpha*16}px ${rgba(glowColor, glowAlpha * 0.12)}`
                    : 'none',
                  transition:'all 0.25s ease',
                  outline:'none',
                }}
              >
                {/* Icon */}
                <span style={{fontSize:18,color: isSelected ? rgba(glowColor, 0.9) : '#2A2D3A', transition:'color 0.25s'}}>
                  {sym.icon}
                </span>
                {/* Label */}
                <span style={{
                  fontFamily:font, fontWeight:300, fontSize:10, letterSpacing:'0.8px',
                  textTransform:'lowercase',
                  color: isSelected ? rgba(glowColor, 0.85) : '#2E3140',
                  transition:'color 0.25s',
                }}>
                  {sym.label}
                </span>
                {/* Intensity watermark */}
                {intensity && (
                  <span style={{
                    fontFamily:font, fontWeight:200, fontSize:9, letterSpacing:'1px',
                    textTransform:'lowercase',
                    color: rgba(glowColor, 0.55),
                    marginTop:2,
                  }}>
                    {intensity}
                  </span>
                )}
              </button>

              {/* × dismiss */}
              {isSelected && (
                <button
                  onClick={e => { e.stopPropagation(); clearSymptom(sym.id) }}
                  style={{
                    position:'absolute', top:-6, right:-6,
                    width:18, height:18, borderRadius:'50%',
                    background:C.surfaceHi,
                    border:`1px solid ${rgba(glowColor, 0.30)}`,
                    color: rgba(glowColor, 0.70),
                    fontSize:10, lineHeight:'18px', textAlign:'center',
                    cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center',
                    outline:'none', padding:0,
                    transition:'all 0.2s',
                  }}
                >
                  ×
                </button>
              )}
            </div>
          )
        })}
      </div>

      {/* Intensity word picker — appears when a symptom is active */}
      <div style={{
        margin:'28px 20px 0',
        height: activeId ? 72 : 0,
        overflow:'hidden',
        transition:'height 0.35s cubic-bezier(0.4,0,0.2,1)',
      }}>
        {activeId && (() => {
          const sym = SYMPTOMS.find(s => s.id === activeId)!
          const entry = entries[activeId]
          return (
            <div style={{
              background: rgba(sym.color, 0.06),
              border:`1px solid ${rgba(sym.color, 0.18)}`,
              borderRadius:12, padding:'14px 16px',
            }}>
              <div style={{...lbl,marginBottom:10,color:rgba(sym.color,0.60),fontSize:9,letterSpacing:'1.8px'}}>
                intensity · {sym.label}
              </div>
              <div style={{display:'flex',gap:8,flexWrap:'wrap'}}>
                {INTENSITY_WORDS.map(word => {
                  const isChosen = entry?.intensity === word
                  return (
                    <button
                      key={word}
                      onClick={() => setIntensity(activeId, word)}
                      style={{
                        fontFamily:font, fontWeight:300, fontSize:11,
                        letterSpacing:'0.8px', textTransform:'lowercase',
                        background: isChosen ? rgba(sym.color, 0.22) : 'transparent',
                        border: isChosen
                          ? `1px solid ${rgba(sym.color, 0.55)}`
                          : `1px solid ${rgba('#ffffff', 0.07)}`,
                        borderRadius:6, padding:'5px 12px',
                        color: isChosen ? rgba(sym.color, 0.95) : '#2E3140',
                        cursor:'pointer', outline:'none',
                        transition:'all 0.18s ease',
                        boxShadow: isChosen ? `0 0 10px ${rgba(sym.color, 0.35)}` : 'none',
                      }}
                    >
                      {word}
                    </button>
                  )
                })}
              </div>
            </div>
          )
        })()}
      </div>

      {/* Selected summary */}
      {selectedIds.length > 0 && (
        <div style={{padding:'24px 20px 0'}}>
          <div style={{...lbl,marginBottom:12,color:'#2A2D38'}}>logged today</div>
          <div style={{display:'flex',flexWrap:'wrap',gap:8}}>
            {selectedIds.map(id => {
              const sym = SYMPTOMS.find(s=>s.id===id)!
              const entry = entries[id]
              return (
                <div key={id} style={{
                  display:'flex', alignItems:'center', gap:6,
                  background: rgba(sym.color, 0.07),
                  border:`1px solid ${rgba(sym.color, 0.20)}`,
                  borderRadius:20, padding:'5px 12px 5px 10px',
                }}>
                  <span style={{fontSize:11,color:rgba(sym.color,0.70)}}>{sym.icon}</span>
                  <span style={{fontFamily:font,fontWeight:300,fontSize:10,letterSpacing:'0.6px',textTransform:'lowercase',color:rgba(sym.color,0.80)}}>
                    {sym.label}
                  </span>
                  {entry.intensity && (
                    <span style={{fontFamily:font,fontWeight:200,fontSize:9,letterSpacing:'0.5px',textTransform:'lowercase',color:rgba(sym.color,0.50),marginLeft:2}}>
                      · {entry.intensity}
                    </span>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Save bar */}
      {selectedIds.length > 0 && (
        <div style={{
          position:'fixed', bottom:52, left:0, right:0,
          padding:'0 20px 12px',
          background:`linear-gradient(to top, ${C.canvas} 60%, transparent)`,
          pointerEvents:'none',
        }}>
          <button style={{
            pointerEvents:'all', width:'100%',
            padding:'15px',
            background: saveCount > 0
              ? 'linear-gradient(135deg, rgba(78,205,196,0.18), rgba(78,205,196,0.08))'
              : rgba('#ffffff', 0.04),
            border:`1px solid ${saveCount > 0 ? rgba(C.curveTeal, 0.40) : rgba('#ffffff',0.08)}`,
            borderRadius:14,
            fontFamily:font, fontWeight:300, fontSize:12,
            letterSpacing:'1.4px', textTransform:'lowercase',
            color: saveCount > 0 ? rgba(C.curveTeal, 0.85) : '#2A2D38',
            cursor:'pointer', outline:'none',
            boxShadow: saveCount > 0 ? `0 0 20px ${rgba(C.curveTeal,0.15)}` : 'none',
            transition:'all 0.3s ease',
          }}>
            {saveCount > 0 ? `save ${saveCount} symptom${saveCount>1?'s':''}` : 'select intensity to save'}
          </button>
        </div>
      )}
    </div>
  )
}

// ─── Root ─────────────────────────────────────────────────────────────────────
export default function App() {
  const [tab, setTab] = useState<'today'|'patterns'|'log'>('log')
  const state = MOCK_STATE
  const font = "'Cormorant Garamond', Georgia, serif"

  const navBtn = (label: string, t: typeof tab): React.CSSProperties => ({
    fontFamily:font, fontWeight:200, fontSize:11,
    letterSpacing:'2px', textTransform:'lowercase',
    background:'none', border:'none', cursor:'pointer',
    padding:'12px 0', flex:1,
    color: tab===t ? '#8BE0D0' : '#2E3140',
    transition:'color 300ms ease',
    position:'relative',
  })

  return (
    <div style={{width:'100%',height:'100vh',background:C.canvas,display:'flex',flexDirection:'column',overflow:'hidden'}}>
      <div style={{flex:1,position:'relative',overflow:'hidden'}}>
        {tab==='today' && (
          <div style={{position:'absolute',inset:0}}>
            <GravityHorizon state={state} />
          </div>
        )}
        {tab==='patterns' && (
          <div style={{position:'absolute',inset:0,overflowY:'auto'}}>
            <SpectrumLog state={state} />
          </div>
        )}
        {tab==='log' && (
          <div style={{position:'absolute',inset:0,overflowY:'auto'}}>
            <SymptomLogger />
          </div>
        )}
      </div>

      {/* Bottom nav */}
      <nav style={{
        display:'flex', background:C.canvas,
        borderTop:`1px solid #1A1D22`,
        paddingBottom:8,
      }}>
        {(['today','log','patterns'] as const).map(t => (
          <button key={t} onClick={()=>setTab(t)} style={navBtn(t,t)}>
            {tab===t && (
              <span style={{
                position:'absolute', top:0, left:'50%', transform:'translateX(-50%)',
                width:20, height:1, background:'#4ECDC4', opacity:0.55, borderRadius:1,
              }} />
            )}
            {t}
          </button>
        ))}
      </nav>
    </div>
  )
}
