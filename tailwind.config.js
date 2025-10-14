module.exports = {
  content: [
    "./lib/**/*.{ex,heex,eex}",
    "./assets/js/**/*.js",
    "./priv/static/**/*.html"
  ],
  safelist: [
    'ring-4',
    'ring-primary'
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