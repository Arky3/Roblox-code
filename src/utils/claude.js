import { storage } from './storage'

const getApiKey = () => {
  return import.meta.env.VITE_ANTHROPIC_API_KEY || storage.getApiKey()
}

export const toBase64 = (file) =>
  new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.readAsDataURL(file)
    reader.onload = () => resolve(reader.result.split(',')[1])
    reader.onerror = reject
  })

export const extractAssignments = async (base64Image, mimeType) => {
  const apiKey = getApiKey()
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'anthropic-dangerous-direct-browser-access': 'true',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1000,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: mimeType,
                data: base64Image,
              },
            },
            {
              type: 'text',
              text: `You are an AI assistant helping students organize their homework.

Look at this image carefully. It may be a photo of a whiteboard, a paper assignment sheet, a screenshot of a learning management system (like Canvas or Google Classroom), or a course syllabus.

Extract ALL assignments, homework, projects, quizzes, tests, or any academic tasks with due dates.

Respond ONLY with a valid JSON array. No preamble, no explanation, no markdown code fences. Just the raw JSON array.

Each item in the array should have these fields:
- "name": string — the assignment or task name
- "subject": string — the subject or class name (infer if not explicit, e.g. "Math", "English", "Biology")
- "dueDate": string — ISO 8601 date format (YYYY-MM-DD). If only a day of the week is given (e.g. "due Friday"), calculate based on today's date: ${new Date().toISOString().split('T')[0]}. If no date found, use 7 days from today.
- "estimatedHours": number — your best estimate of how many hours this will take (0.5 to 8)
- "notes": string — any additional context about the assignment (can be empty string)

If no assignments are found, return an empty array [].

Example output format:
[
  {
    "name": "Chapter 5 Reading",
    "subject": "AP Biology",
    "dueDate": "2025-09-15",
    "estimatedHours": 1.5,
    "notes": "Pages 112-134"
  }
]`,
            },
          ],
        },
      ],
    }),
  })

  if (!response.ok) {
    const err = await response.json().catch(() => ({}))
    throw new Error(err?.error?.message || `API error ${response.status}`)
  }

  const data = await response.json()
  const text = data.content?.find((b) => b.type === 'text')?.text || '[]'

  try {
    return JSON.parse(text)
  } catch {
    const cleaned = text.replace(/```json|```/g, '').trim()
    return JSON.parse(cleaned)
  }
}

export const generateStudyPlan = async (assignments) => {
  const apiKey = getApiKey()
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'anthropic-dangerous-direct-browser-access': 'true',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1000,
      messages: [
        {
          role: 'user',
          content: `You are a smart academic planner. A student has the following assignments:

${JSON.stringify(assignments, null, 2)}

Today's date is: ${new Date().toISOString().split('T')[0]}

The student has approximately 2 study hours available on weekdays and 4 hours on weekends.

For each assignment, calculate a "startByDate" — the latest date they should START working on it to finish on time, based on the estimated hours and available daily study time.

Also determine if this week (the next 7 days) is a "danger week" — more than 8 total hours of work due.

Respond ONLY with a valid JSON object. No preamble, no markdown. Raw JSON only.

Format:
{
  "plan": [
    {
      "name": "assignment name exactly as given",
      "startByDate": "YYYY-MM-DD",
      "urgency": "high" | "medium" | "low"
    }
  ],
  "dangerWeek": true | false,
  "totalHoursThisWeek": number,
  "weekSummary": "One sentence summary of how busy this week is"
}`,
        },
      ],
    }),
  })

  if (!response.ok) {
    const err = await response.json().catch(() => ({}))
    throw new Error(err?.error?.message || `API error ${response.status}`)
  }

  const data = await response.json()
  const text = data.content?.find((b) => b.type === 'text')?.text || '{}'

  try {
    return JSON.parse(text)
  } catch {
    const cleaned = text.replace(/```json|```/g, '').trim()
    return JSON.parse(cleaned)
  }
}
