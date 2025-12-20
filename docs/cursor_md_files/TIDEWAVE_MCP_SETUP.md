# Tidewave MCP Setup & Usage Guide

## ✅ Installation Complete

Tidewave Phoenix MCP is **fully configured** in this project! Here's what's already set up:

### 1. Dependency Installed
```elixir
# mix.exs line 72
{:tidewave, "~> 0.5", only: [:dev]}
```

### 2. Endpoint Configuration
```elixir
# lib/qlarius_web/endpoint.ex lines 54-56
if Code.ensure_loaded?(Tidewave) do
  plug Tidewave
end
```

### 3. LiveView Debug Options
```elixir
# config/dev.exs lines 111-117
config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
```

---

## 🚀 How to Use Tidewave MCP

### Starting Your Development Server

1. **Start your Phoenix server**:
```bash
mix phx.server
```

2. **Access Tidewave**:
   - Tidewave runs on the same port as your Phoenix server
   - URL: `http://localhost:4000` (or `https://localhost:4001` if using HTTPS)

### Connecting to Cursor

#### Option 1: Direct MCP Connection
Add this to your Cursor MCP settings:

```json
{
  "mcpServers": {
    "qlarius-tidewave": {
      "url": "http://localhost:4000"
    }
  }
}
```

#### Option 2: Using Tidewave CLI
If you have the Tidewave CLI installed:

```bash
tidewave connect http://localhost:4000
```

---

## 🎯 What Tidewave Provides

### MCP Tools Available

Tidewave exposes powerful tools via Model Context Protocol:

1. **File Operations**
   - Read/write files in your project
   - Navigate directory structure
   - Edit code with context awareness

2. **Database Operations**
   - Query Ecto schemas
   - Inspect database state
   - Run migrations
   - Test database queries

3. **Phoenix Context**
   - List LiveViews and routes
   - Inspect component definitions
   - View HEEx templates
   - Access configuration

4. **Code Intelligence**
   - Search for functions/modules
   - Find references
   - View documentation
   - Understand dependencies

5. **Testing & Development**
   - Run tests
   - View test output
   - Debug LiveView states
   - Inspect assigns

### Web Interface

When your server is running, you can also access Tidewave's web interface:

1. Navigate to: `http://localhost:4000/_tidewave`
2. Browse your project structure
3. Test database queries
4. Explore routes and LiveViews
5. View component documentation

---

## 🔧 Configuration Options

### Basic Configuration
In `lib/qlarius_web/endpoint.ex`, you can customize Tidewave:

```elixir
if Code.ensure_loaded?(Tidewave) do
  plug Tidewave,
    allow_remote_access: false,  # Default: only localhost
    inspect_opts: [
      charlists: :as_lists,
      limit: 100,                 # Increase for more data
      pretty: true
    ],
    team: [id: "qlarius"]         # Optional: team identifier
end
```

### Allow Remote Access (Development Only)
**⚠️ Only enable in trusted networks:**

```elixir
plug Tidewave, allow_remote_access: true
```

### Multiple Hosts/Subdomains
If using multiple development subdomains (e.g., `admin.localhost`, `app.localhost`):

```elixir
# In lib/qlarius_web/endpoint.ex
@session_options [
  # ... existing options
]

if code_reloading? do
  @session_options Keyword.merge(@session_options, 
    same_site: "None", 
    secure: true
  )
end
```

---

## 🧪 Testing Tidewave

### Verify Installation

1. **Start the server**:
```bash
mix phx.server
```

2. **Check the logs** for Tidewave initialization:
```
[info] Tidewave MCP server started
[info] Access Tidewave at http://localhost:4000/_tidewave
```

3. **Test the endpoint**:
```bash
curl http://localhost:4000/_tidewave
```

### Example MCP Queries

Once connected to Cursor, try these commands:

**List all routes:**
```
List all Phoenix routes in the application
```

**Find a specific function:**
```
Show me the implementation of the user registration function
```

**Query database:**
```
Show me all User records in the database
```

**Inspect LiveView:**
```
Show me the current state of the QlinkPageLive component
```

---

## 🐛 Troubleshooting

### Issue: Can't connect to Tidewave

**Solution:** Ensure your Phoenix server is running and accessible:
```bash
mix phx.server
# Should see: "Running QlariusWeb.Endpoint with Bandit 1.8.0 at :::4000 (http)"
```

### Issue: "Module not loaded" error

**Solution:** Tidewave is dev-only. Ensure you're in development mode:
```bash
MIX_ENV=dev mix phx.server
```

### Issue: CORS errors when accessing from browser

**Solution:** Check your Content-Security-Policy in `endpoint.ex`:
```elixir
# Your current CSP includes chrome-extension support
# Tidewave should work with your existing settings
```

### Issue: Tidewave not appearing in MCP

**Solution:** Verify the plug is loaded:
```bash
mix compile --force
mix phx.server
```

---

## 📚 Resources

- **Tidewave GitHub**: https://github.com/tidewave-ai/tidewave_phoenix
- **MCP Documentation**: https://modelcontextprotocol.io
- **Phoenix LiveView**: https://hexdocs.pm/phoenix_live_view

---

## 🎓 Tips for AI-Assisted Development

### Best Practices

1. **Start Specific**: Ask about specific files or functions
   - ✅ "Show me the user registration changeset"
   - ❌ "Show me everything about users"

2. **Leverage Context**: Tidewave understands your Ecto schemas, LiveViews, and routes
   - "What fields are in the User schema?"
   - "List all routes that require admin permissions"

3. **Test Queries**: Use Tidewave to test Ecto queries before implementing
   - "Test a query that finds all users created this month"

4. **Explore Dependencies**: Understand how modules interact
   - "What functions in Accounts context call the User schema?"

5. **Debug LiveView**: Inspect state and assigns
   - "Show current assigns in RegistrationLive"

### Integration with Cursor

Tidewave enhances Cursor's understanding of your Phoenix project by:

- Providing real-time database state
- Showing actual route definitions
- Accessing compiled code and documentation
- Understanding LiveView component structure
- Exposing Ecto schema relationships

This means **more accurate code generation** and **better contextual understanding** when working with AI assistants!

---

## ✨ You're All Set!

Tidewave MCP is ready to use. Just:
1. `mix phx.server`
2. Connect via Cursor MCP settings
3. Start building with enhanced AI assistance!

