module.exports = {
  content: [
    "./lib/**/*.{ex,heex,eex}",
    "./assets/js/**/*.js",
    "./priv/static/**/*.html"
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
    themes: [
      {
        qlarius: {
          "primary": "#8B5CF6",
          "primary-content": "#FFFFFF", 
          "secondary": "#F59E0B",
          "accent": "#EF4444",
          "neutral": "#374151",
          "base-100": "#FFFFFF",
          "info": "#3ABFF8",
          "success": "#36D399", 
          "warning": "#FBBD23",
          "error": "#F87272",
        },
      },
      "light",
      "dark"
    ],
  },
} 