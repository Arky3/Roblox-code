/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        cream:  '#F5F0E8',
        sage:   '#4A6741',
        'sage-light': '#5C7D53',
        'sage-dark':  '#3A5231',
        amber:  '#8A6A10',
        bark:   '#2C1F14',
        muted:  '#8A8278',
        card:   '#FFFCF7',
        border: '#E0D8CC',
      },
      fontFamily: {
        sans:    ['DM Sans', 'sans-serif'],
        display: ['Cormorant Garamond', 'serif'],
      },
    },
  },
  plugins: [],
}
