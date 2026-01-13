alias Qlarius.System

# Default notification CTAs - one per line for easy admin editing
default_ctas = """
Tap to access and sell your attention now.
Tap now and let's grab that revenue!
Fuel your wallet now for easy spending later!
Oh by the way - the ads match you perfectly!
Time to turn your attention into cash!
Your sponsors are waiting - tap to engage!
Easy money is just a tap away!
These ads were picked just for you!
Let's make some quick cash together!
Your personalized ads are ready to view!
"""

System.set_global_variable("notification_ctas", String.trim(default_ctas))

IO.puts("✅ Notification CTAs seeded (editable at /admin/global_variables)")
