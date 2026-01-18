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
      }
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