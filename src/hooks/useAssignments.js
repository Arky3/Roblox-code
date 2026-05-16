import { useState, useCallback } from 'react'
import { storage } from '../utils/storage'
import { ensureSubjectColors } from '../utils/colors'

export const useAssignments = () => {
  const [assignments, setAssignments] = useState(() => storage.getAssignments())

  const save = useCallback((updated) => {
    storage.saveAssignments(updated)
    setAssignments(updated)
  }, [])

  const addAssignments = useCallback(
    (newOnes) => {
      const withColors = ensureSubjectColors(newOnes)
      const existing = storage.getAssignments()
      save([...existing, ...withColors])
    },
    [save]
  )

  const updateAssignment = useCallback(
    (id, changes) => {
      const updated = storage.getAssignments().map((a) =>
        a.id === id ? { ...a, ...changes } : a
      )
      save(updated)
    },
    [save]
  )

  const deleteAssignment = useCallback(
    (id) => {
      const updated = storage.getAssignments().filter((a) => a.id !== id)
      save(updated)
    },
    [save]
  )

  const toggleComplete = useCallback(
    (id) => {
      const updated = storage.getAssignments().map((a) =>
        a.id === id ? { ...a, completed: !a.completed } : a
      )
      save(updated)
    },
    [save]
  )

  const clearAll = useCallback(() => {
    save([])
    storage.clearAll()
  }, [save])

  return { assignments, addAssignments, updateAssignment, deleteAssignment, toggleComplete, clearAll }
}
