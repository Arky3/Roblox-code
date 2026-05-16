const ASSIGNMENTS_KEY = 'snapStudy_assignments'
const SETTINGS_KEY = 'snapStudy_settings'
const COLORS_KEY = 'snapStudy_subjectColors'
const API_KEY_KEY = 'snapStudy_apiKey'

export const storage = {
  getAssignments: () => {
    try {
      return JSON.parse(localStorage.getItem(ASSIGNMENTS_KEY) || '[]')
    } catch {
      return []
    }
  },

  saveAssignments: (assignments) => {
    localStorage.setItem(ASSIGNMENTS_KEY, JSON.stringify(assignments))
  },

  getSettings: () => {
    try {
      return JSON.parse(localStorage.getItem(SETTINGS_KEY) || 'null')
    } catch {
      return null
    }
  },

  saveSettings: (settings) => {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings))
  },

  getSubjectColors: () => {
    try {
      return JSON.parse(localStorage.getItem(COLORS_KEY) || '{}')
    } catch {
      return {}
    }
  },

  saveSubjectColors: (colors) => {
    localStorage.setItem(COLORS_KEY, JSON.stringify(colors))
  },

  getApiKey: () => {
    return localStorage.getItem(API_KEY_KEY) || ''
  },

  saveApiKey: (key) => {
    localStorage.setItem(API_KEY_KEY, key)
  },

  clearAll: () => {
    localStorage.removeItem(ASSIGNMENTS_KEY)
    localStorage.removeItem(COLORS_KEY)
  },
}
