/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        bg: '#0a0a0f',
        surface: '#13131a',
        border: '#1e1e2e',
        primary: '#4f8ef7',
        secondary: '#22d3a5',
        'text-primary': '#f0f0f5',
        'text-muted': '#6b6b80',
        danger: '#f75555',
        warning: '#f7a844',
      },
      fontFamily: {
        sans: ['DM Sans', 'sans-serif'],
      },
      animation: {
        'pulse-slow': 'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'spin-slow': 'spin 3s linear infinite',
        'border-dash': 'borderDash 1s linear infinite',
      },
      keyframes: {
        borderDash: {
          '0%': { strokeDashoffset: '0' },
          '100%': { strokeDashoffset: '-20' },
        }
      }
    },
  },
  plugins: [],
}
