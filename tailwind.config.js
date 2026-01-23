module.exports = {
  content: [
    "./lib/**/*.{ex,heex,eex}",
    "./assets/js/**/*.js",
    "./priv/static/**/*.html"
  ],
  safelist: [
    'ring-4',
    'ring-primary',
    'tabs',
    'tabs-boxed',
    'tab',
    'tab-active',
    'badge',
    'badge-primary',
    'badge-sm',
    'bg-sponster-500',
    'rounded-full'
  ],
  theme: {
    extend: {
      colors: {
        sponster: {
          500: "#43B274"
        },
      },
      transitionTimingFunction: {
        'ease-in-out': 'cubic-bezier(0.4, 0, 0.2, 1)',
      },
      keyframes: {
        'fade-in': {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        'fade-out': {
          '0%': { opacity: '1' },
          '100%': { opacity: '0' },
        },
      },
      animation: {
        'fade-in': 'fade-in 0.5s ease-in-out',
        'fade-out': 'fade-out 0.5s ease-in-out',
      },
    },
  },
  plugins: [
    require('daisyui')
  ],
  daisyui: {
    base: false,
    themes: [
      "light",
      "dark"
    ]
  },
} 