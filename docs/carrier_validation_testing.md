# Carrier Validation Testing Guide

## Overview

This guide explains how to test different phone carrier types (VOIP, landline, mobile) during development.

---

## 🧪 Testing Strategies

### 1. Test with Real Services (Recommended)

#### VOIP Numbers (Should be REJECTED ❌)

Get free/paid numbers from these services:

| Service | Type | Cost | URL |
|---------|------|------|-----|
| **Google Voice** | VOIP | Free | [voice.google.com](https://voice.google.com) |
| **TextNow** | VOIP | Free | [textnow.com](https://textnow.com) |
| **Skype Number** | VOIP | Paid | [skype.com](https://skype.com) |
| **Burner App** | VOIP | Paid | [burnerapp.com](https://burnerapp.com) |

**Why this works:** Twilio's Line Type Intelligence API correctly identifies these as `type: "voip"`

#### Landline Numbers (Should be REJECTED ❌)

- Use your home phone or office landline
- Borrow a friend's landline number for testing

#### Mobile Numbers (Should be ACCEPTED ✅)

- Your personal mobile number
- Test with different carriers (AT&T, Verizon, T-Mobile, etc.)
- Ask team members with different carriers to test

---

### 2. Development Mode Toggle

For rapid testing without carrier restrictions:

#### Enable Skip Mode

Edit `config/dev.exs`:

```elixir
config :qlarius, skip_carrier_validation: true  # ← Set to true
```

**Restart your server:**
```bash
# In server terminal
Ctrl+C (twice)
mix phx.server
```

**What happens:**
- ✅ ALL phone numbers pass carrier validation
- ⚠️ You'll see a warning in logs: `Carrier validation SKIPPED (dev mode)`
- 📱 Carrier info shows: "DEV MODE - Validation Skipped"

#### Disable Skip Mode (Test Real Validation)

```elixir
config :qlarius, skip_carrier_validation: false  # ← Set to false (default)
```

Restart server and test with real carrier validation logic.

---

### 3. Testing Specific Scenarios

#### Test Case 1: VOIP Number (Should Reject)

1. Get a Google Voice number (free)
2. Set `skip_carrier_validation: false`
3. Try to register
4. **Expected:** Error message: *"VOIP numbers are not supported. Please use a mobile number from a major carrier"*

#### Test Case 2: Non-Whitelisted Carrier

1. Find a mobile number from a smaller carrier (e.g., TracFone, PagePlus)
2. Try to register
3. **Expected:** Error message: *"We currently only support major US carriers. Your carrier: [name]"*
4. **Check logs** for warning message with carrier name

#### Test Case 3: Whitelisted Carrier (Should Accept)

1. Use your personal mobile from AT&T/Verizon/T-Mobile
2. Complete verification
3. **Expected:** Success with carrier info displayed:
   ```
   ✅ Phone number verified: 5551234567
      Carrier: AT&T Wireless    Country: US    Type: Mobile
   ```

#### Test Case 4: Non-US Number

1. Try a Canadian number: `+14165551234`
2. **Expected:** Error: *"We currently only support US phone numbers"*

---

## 📊 Monitoring & Logging

### Find Rejected Carriers in Logs

When a legitimate carrier is rejected, check your logs:

```bash
# In your terminal or log file
[warning] Carrier not in whitelist 
  carrier="Straight Talk Wireless" 
  phone_number="+15551234567"
  full_info=%{type: "mobile", carrier_name: "Straight Talk Wireless", ...}
```

### Add Rejected Carrier to Whitelist

1. Edit `lib/qlarius/services/twilio.ex`
2. Add carrier name to `@allowed_carriers` list (around line 35):

```elixir
@allowed_carriers [
  "AT&T Wireless",
  "Verizon Wireless",
  # ... existing carriers ...
  "Straight Talk Wireless"  # ← Add new carrier
]
```

3. Run `mix compile`
4. Restart server

---

## 🔧 Troubleshooting

### Issue: SMS Not Sending to Test Number

**Problem:** Public test numbers (like TestNumber.org) can't receive SMS

**Solution:** Use real VOIP services (Google Voice, TextNow) that CAN receive SMS

### Issue: All Numbers Passing Validation

**Check:**
1. Is `skip_carrier_validation: true` in `config/dev.exs`?
2. Did you restart the server after changing config?
3. Check logs for "Carrier validation SKIPPED" message

### Issue: Twilio Lookup API Errors

**Common causes:**
- Twilio credentials not set
- Line Type Intelligence add-on not enabled in Twilio account
- API rate limits exceeded

**Check logs for:**
```
[error] Twilio lookup failed: 404 - ...
```

### Issue: Can't Test Multiple Carriers

**Solution:** Ask team members or friends with different carriers to test, or:
1. Buy prepaid SIMs from different carriers ($10-20 each)
2. Test with family members' numbers
3. Use old phone numbers you control

---

## 🎯 Testing Checklist

Before deploying carrier validation:

- [ ] Test VOIP rejection (Google Voice)
- [ ] Test landline rejection
- [ ] Test AT&T mobile acceptance
- [ ] Test Verizon mobile acceptance
- [ ] Test T-Mobile mobile acceptance
- [ ] Test non-US number rejection
- [ ] Test unknown/small carrier rejection
- [ ] Verify carrier info displays correctly
- [ ] Check logs for rejected carriers
- [ ] Verify skip mode works (dev only)
- [ ] Test with `skip_carrier_validation: false` before production

---

## 🚀 Production Deployment

**Before going to production:**

1. Set `skip_carrier_validation: false` in `config/prod.exs` (or remove it - false is default)
2. Monitor logs for rejected carriers in first week
3. Update whitelist based on legitimate rejections
4. Consider adding more carriers gradually

**Never set `skip_carrier_validation: true` in production!**

---

## 📚 Additional Resources

- [Twilio Line Type Intelligence Docs](https://www.twilio.com/docs/lookup/v2-api/line-type-intelligence)
- [TestNumber.org](https://testnumber.org) - Test call interoperability
- [FreeSWITCH Test Numbers](https://developer.signalwire.com/freeswitch/confluence-to-docs-redirector/display/FREESWITCH/Test%2BNumbers)

---

## 💡 Tips

1. **Google Voice is your best friend** for VOIP testing - it's free and receives SMS
2. **Log everything** - Rejected carriers show up in logs with full details
3. **Start strict, loosen gradually** - Better to reject unknown carriers initially
4. **Ask users** - If legitimate users are rejected, they'll contact support
5. **Update regularly** - Carrier names change, new MVNOs appear

