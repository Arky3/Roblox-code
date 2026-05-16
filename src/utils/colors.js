import { SUBJECT_COLORS } from '../constants'
import { storage } from './storage'

export const getSubjectColor = (subject) => {
  const colorMap = storage.getSubjectColors()

  if (colorMap[subject]) {
    return colorMap[subject]
  }

  const usedCount = Object.keys(colorMap).length
  const color = SUBJECT_COLORS[usedCount % SUBJECT_COLORS.length]
  colorMap[subject] = color
  storage.saveSubjectColors(colorMap)
  return color
}

export const ensureSubjectColors = (assignments) => {
  return assignments.map((a) => ({
    ...a,
    subjectColor: a.subjectColor || getSubjectColor(a.subject),
  }))
}
