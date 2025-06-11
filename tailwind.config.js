module.exports = {
  content: [
    "./lib/**/*.{ex,heex,eex}",
    "./assets/js/**/*.js",
    "./priv/static/**/*.html"
  ],
  theme: {
    extend: {
      colors: {
        // Example: additional custom colors if needed
        'qlarius-blue': '#3B82F6',
        'qlarius-green': '#10B981',
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
      "dark",
    ],
  },
} 