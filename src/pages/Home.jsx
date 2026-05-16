import { useNavigate } from 'react-router-dom'
import UploadZone from '../components/UploadZone'

export default function Home() {
  const navigate = useNavigate()

  const handleFile = (file) => {
    const url = URL.createObjectURL(file)
    navigate('/scan', { state: { file, previewUrl: url } })
  }

  return (
    <div className="min-h-screen bg-[#0a0a0f] flex flex-col items-center justify-center px-6 py-24">
      <div className="w-full max-w-xl">
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 bg-[#4f8ef7]/10 border border-[#4f8ef7]/20 rounded-full px-4 py-1.5 mb-6">
            <span className="text-xs font-semibold text-[#4f8ef7] uppercase tracking-widest">Beta</span>
          </div>
          <h1 className="text-5xl font-bold text-[#f0f0f5] mb-4 leading-tight">
            Point. Scan.{' '}
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#4f8ef7] to-[#22d3a5]">
              Done.
            </span>
          </h1>
          <p className="text-[#6b6b80] text-lg max-w-md mx-auto leading-relaxed">
            Take a photo of your whiteboard, assignment sheet, or Canvas — AI extracts every due date and builds your study schedule automatically.
          </p>
        </div>

        <UploadZone onFile={handleFile} />

        <div className="flex items-center justify-center gap-3 mt-6 flex-wrap">
          {['📷 Whiteboard', '📄 Paper handout', '🖥 Canvas screenshot'].map((chip) => (
            <span
              key={chip}
              className="text-xs font-medium text-[#6b6b80] bg-[#13131a] border border-[#1e1e2e] rounded-full px-3 py-1.5"
            >
              {chip}
            </span>
          ))}
        </div>

        <div className="text-center mt-10">
          <button
            onClick={() => navigate('/dashboard')}
            className="text-sm text-[#6b6b80] hover:text-[#4f8ef7] transition-colors underline underline-offset-4"
          >
            View My Assignments →
          </button>
        </div>
      </div>

      {/* Ambient glow */}
      <div className="fixed top-1/4 left-1/2 -translate-x-1/2 w-96 h-96 bg-[#4f8ef7]/5 rounded-full blur-3xl pointer-events-none" />
      <div className="fixed top-1/3 left-1/3 w-64 h-64 bg-[#22d3a5]/5 rounded-full blur-3xl pointer-events-none" />
    </div>
  )
}
