# Current Marketer Implementation: Why localStorage?

## TL;DR

We use **browser localStorage** instead of Phoenix session because LiveView sessions are read-only after mount, making runtime session modification incompatible with the LiveView architecture.

## The Problem with Phoenix Sessions in LiveView

### Session Lifecycle in LiveView
1. **HTTP Request** → Session established (cookies decoded)
2. **mount/3** → Session values read
3. **WebSocket Upgrade** → Session becomes read-only
4. **LiveView Events** → Cannot modify session

### Why `put_session/3` Doesn't Work

While `Phoenix.LiveView.put_session/3` exists in the API, it's meant for specific edge cases and isn't reliable for general use because:

- LiveView runs over WebSockets after initial mount
- Session state is tied to the original HTTP connection
- There's no mechanism to "send back" session updates to the client cookie
- The function may be undefined or private in some LiveView versions

```elixir
# This DOESN'T work reliably in LiveView events:
def handle_event("set_value", _params, socket) do
  socket
  |> put_session(:my_value, "foo")  # ❌ Warning: undefined or has no effect
  |> noreply()
end
```

## Why localStorage is the Right Choice

### 1. **Matches the Use Case**
- ✅ Need: Persistent selection across page navigations
- ✅ Need: Survives browser restarts (indefinite storage)
- ✅ Need: Fast, client-side access
- ✅ Need: Works with LiveView's event model

### 2. **Simple Integration with LiveView**
```javascript
// JS Hook - Clean separation of concerns
Hooks.CurrentMarketer = {
  mounted() {
    // Load from localStorage on mount
    const id = localStorage.getItem('current_marketer_id')
    if (id) {
      this.pushEvent('load_current_marketer', { marketer_id: id })
    }
    
    // Save to localStorage when instructed
    this.handleEvent('store_current_marketer', ({ marketer_id }) => {
      localStorage.setItem('current_marketer_id', marketer_id)
    })
  }
}
```

```elixir
# LiveView - Standard event handlers
def handle_event("load_current_marketer", %{"marketer_id" => id}, socket) do
  {:noreply, assign(socket, :current_marketer_id, id)}
end

def handle_event("set_current_marketer", %{"id" => id}, socket) do
  {:noreply,
   socket
   |> assign(:current_marketer_id, id)
   |> push_event("store_current_marketer", %{marketer_id: id})}
end
```

### 3. **Works with LiveView Architecture**
- ✅ Respects the WebSocket model
- ✅ No fighting against framework limitations  
- ✅ Clear data flow: Browser ↔ localStorage ↔ LiveView assigns
- ✅ No warnings or undefined function errors

## Alternative Approaches Considered

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **Phoenix Session** | Server-controlled, integrated | Read-only in LiveView, doesn't work for events | ❌ Incompatible |
| **Database Table** | Persistent, server-side | Requires migrations, DB overhead, complex | ❌ Over-engineered |
| **ETS/Process State** | Fast, server-side | Loses data on server restart | ❌ Not persistent |
| **Cookies via JS** | Persistent, works | More complex than localStorage | ⚠️ Possible but unnecessary |
| **localStorage** | Simple, persistent, fast, works perfectly | Client-side only | ✅ **Best fit** |

## Trade-offs We Accept

### localStorage Limitations
1. **Client-side only** - Can't be read server-side before LiveView mounts
   - *Not an issue*: We load it on mount via the JS hook
   
2. **Per-browser** - Different browsers have different selections
   - *Acceptable*: This is actually desired behavior for admin tools
   
3. **Can be cleared** - User can clear browser data
   - *Acceptable*: Easily re-selectable, not critical data

4. **~10MB limit** - Storage limit per domain
   - *Not an issue*: We're storing one small ID

## Security Considerations

### Is it safe to store marketer_id in localStorage?

✅ **Yes, for this use case:**

1. **Admin-only feature** - Only accessible to authenticated admin users
2. **Non-sensitive data** - Just an ID for UI context, not auth data
3. **Server-side validation** - All actual operations validate permissions server-side
4. **Read-only impact** - If manipulated, only affects which marketer's campaigns are shown

### What we DON'T store in localStorage:
- ❌ Auth tokens
- ❌ Session IDs  
- ❌ Passwords
- ❌ Sensitive user data

### What we DO validate server-side:
- ✅ User has admin permissions
- ✅ Marketer exists
- ✅ User can access that marketer's data

## Conclusion

**localStorage + LiveView hooks is the correct, idiomatic solution for this use case.**

It provides:
- ✅ Persistent storage (indefinite)
- ✅ Simple implementation (~15 lines of JS)
- ✅ No framework limitations or warnings
- ✅ Fast, reliable, battle-tested
- ✅ Clear separation of concerns

The attempted "Phoenix-only" solution failed because it fought against LiveView's architecture. localStorage embraces it.

