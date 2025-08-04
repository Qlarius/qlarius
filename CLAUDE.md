# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Qlarius is a Phoenix LiveView application for managing advertising campaigns and user data. It provides features for:
- User trait management and categorization
- Ad campaign creation and targeting
- Media piece management and sequencing
- Survey management
- Wallet/payment systems
- Content arcade functionality

## Tech Stack

- **Backend**: Elixir with Phoenix Framework (~1.8.0)
- **Database**: PostgreSQL with Ecto
- **Frontend**: Phoenix LiveView, Alpine.js, TailwindCSS v4, DaisyUI
- **File Storage**: Waffle (local in dev, S3 in production)
- **Authentication**: bcrypt_elixir with custom UserAuth module
- **Build Tools**: esbuild for JS, TailwindCSS CLI for CSS

## Development Commands

### Setup
```bash
mix setup  # Install dependencies, create DB, run migrations, and build assets
```

### Running the Application
```bash
mix phx.server  # Start Phoenix server
iex -S mix phx.server  # Start Phoenix server with interactive shell
```

### Database
```bash
mix ecto.create  # Create database
mix ecto.migrate  # Run migrations
mix ecto.reset  # Drop, create, and migrate database
mix ecto.rollback  # Rollback last migration
```

### Testing
```bash
mix test  # Run all tests
mix test path/to/test.exs  # Run specific test file
mix test path/to/test.exs:42  # Run specific test at line 42
```

### Code Quality
```bash
mix format  # Format code
mix format --check-formatted  # Check if code is formatted
mix credo  # Run static code analysis
mix credo --strict  # Run stricter analysis
```

### Assets
```bash
cd assets && npm install  # Install JavaScript dependencies
cd assets && npm run build  # Build CSS and JS
cd assets && npm run watch  # Watch and rebuild CSS/JS on changes
```

## Project Structure

- `lib/qlarius/` - Core business logic contexts
  - `accounts/` - User authentication and management
  - `sponster/` - Ad campaigns, media pieces, offers
  - `tiqit/` - Content arcade functionality
  - `wallets/` - Payment and ledger systems
  - `youdata/` - User traits, surveys, and personal data

- `lib/qlarius_web/` - Web layer
  - `controllers/` - Phoenix controllers
  - `live/` - LiveView modules
  - `components/` - Reusable UI components
  - `layouts/` - Application layouts
  - `router.ex` - Route definitions

- `priv/repo/migrations/` - Database migrations
- `assets/` - Frontend assets (JS, CSS)
- `test/` - Test files

## Key Patterns

### Context Design
The application follows Phoenix's context pattern with bounded contexts for different domains:
- `Qlarius.Accounts` - User management
- `Qlarius.Sponster.Marketing` - Campaign management
- `Qlarius.Youdata.Traits` - User trait management
- `Qlarius.Wallets` - Financial transactions

### LiveView Usage
LiveView is extensively used for interactive UIs. Common patterns:
- Form components use `handle_event` callbacks
- Real-time updates via PubSub
- Component-based UI with `live_component`

### Authentication
- Custom authentication using `QlariusWeb.UserAuth`
- Session-based authentication
- HTTP Basic Auth for marketer routes (username: "marketer", password: "password")

### Testing Approach
- Unit tests for contexts using `DataCase`
- Controller tests using `ConnCase`
- Fixtures defined in `test/support/fixtures/`
- Test helpers for authentication in test environment

## Important Notes

- The application uses a multi-tenant scope system configured in `config.exs`
- File uploads are handled through Waffle with local storage in development
- CORS is configured for widget embedding
- The application supports iframe embedding for widgets
- Database schema was migrated from a legacy Rails application (see `legacy_structure.sql`)

## Common Development Tasks

### Adding a New Context
1. Create context module in `lib/qlarius/`
2. Define schemas in context subdirectory
3. Add tests in `test/qlarius/`
4. Update router if web access needed

### Creating a LiveView
1. Create LiveView module in `lib/qlarius_web/live/`
2. Add route in `router.ex`
3. Create corresponding `.html.heex` template
4. Add tests in `test/qlarius_web/live/`

### Running Database Seeds
```bash
mix run priv/repo/seeds.exs
```

### Debugging
- Use `IEx.pry` for breakpoints
- Check logs with `mix phx.server` output
- LiveDashboard available at `/dev/dashboard` in development