/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: '#F26522',
          50:  '#fff4ee',
          100: '#ffe4d0',
          200: '#ffc49d',
          300: '#ff9c62',
          400: '#f97832',
          500: '#F26522',
          600: '#d4541a',
          700: '#b84410',
          glow: 'rgba(242,101,34,0.15)',
        },
        purple: {
          DEFAULT: '#9333EA',
          500: '#9333EA',
          600: '#7c28cc',
          glow: 'rgba(147,51,234,0.20)',
        },
        surface: {
          DEFAULT: '#0C0A18',
          card:    '#141128',
          elevated:'#1E1838',
          border:  '#3D3060',
          muted:   '#6B6185',
        },
        myraba: {
          text:    '#FFFFFF',
          second:  '#B0A8C8',
          hint:    '#6B6185',
          success: '#10B981',
          gold:    '#F59E0B',
          error:   '#EF4444',
          info:    '#3B82F6',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
    },
  },
  plugins: [],
}

