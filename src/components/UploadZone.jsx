import { useState, useRef, useCallback } from 'react'

export default function UploadZone({ onFile }) {
  const [dragging, setDragging] = useState(false)
  const inputRef = useRef(null)

  const handleFile = useCallback((file) => {
    if (!file) return
    if (!file.type.startsWith('image/')) {
      alert('Please upload an image file (jpg, png, webp)')
      return
    }
    onFile(file)
  }, [onFile])

  const onDrop = useCallback((e) => {
    e.preventDefault()
    setDragging(false)
    const file = e.dataTransfer.files[0]
    handleFile(file)
  }, [handleFile])

  const onDragOver = (e) => { e.preventDefault(); setDragging(true) }
  const onDragLeave = () => setDragging(false)
  const onChange = (e) => handleFile(e.target.files[0])

  return (
    <div
      onDrop={onDrop}
      onDragOver={onDragOver}
      onDragLeave={onDragLeave}
      onClick={() => inputRef.current?.click()}
      className={`relative cursor-pointer rounded-2xl p-12 text-center transition-all duration-200 ${
        dragging
          ? 'bg-[#4f8ef7]/10 border-2 border-[#4f8ef7] scale-[1.01]'
          : 'bg-[#13131a] border-2 border-dashed border-[#1e1e2e] hover:border-[#4f8ef7]/50 hover:bg-[#13131a]/80'
      }`}
      style={dragging ? { boxShadow: '0 0 40px rgba(79,142,247,0.15)' } : {}}
    >
      <input
        ref={inputRef}
        type="file"
        accept="image/*"
        onChange={onChange}
        className="hidden"
      />

      <div className="flex flex-col items-center gap-4">
        <div className={`w-16 h-16 rounded-2xl flex items-center justify-center text-3xl transition-all ${
          dragging ? 'bg-[#4f8ef7]/20 scale-110' : 'bg-[#1e1e2e]'
        }`}>
          📷
        </div>

        <div>
          <p className="text-[#f0f0f5] font-semibold text-lg mb-1">
            {dragging ? 'Drop it here!' : 'Drop a photo here'}
          </p>
          <p className="text-[#6b6b80] text-sm">
            or <span className="text-[#4f8ef7] underline underline-offset-2">click to browse</span>
          </p>
          <p className="text-[#6b6b80] text-xs mt-2">
            Supports jpg, png, webp · whiteboard, handout, Canvas screenshot
          </p>
        </div>
      </div>
    </div>
  )
}
