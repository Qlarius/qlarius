defmodule Qlarius.Nudges.Catalog do
  @moduledoc """
  Every nudge Qadabra can suggest.

  Each entry looks at the context built by `Qlarius.Nudges` and returns a
  `%Nudge{}` when it applies right now, or nil when it does not. Keys are
  stored in `me_file_nudges`, so renaming a key resets its history.

  To add a nudge: write a function here, add it to `nudges/1`, and give it a
  key, a brand, and an `href`. Add any data it needs to `Nudges.context/2`.
  """

  alias Qlarius.Nudges.Nudge

  def nudges(context) do
    [
      essentials(context),
      tag_goal(context),
      notifications(context),
      invite(context)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp essentials(%{essentials: %{answered: answered, total: total, survey_id: survey_id}})
       when total > 0 and answered < total do
    %Nudge{
      key: "essentials",
      brand: :youdata,
      icon: "hero-identification",
      graphic: "/images/nudges/essentials.svg",
      graphic_dark: "/images/nudges/essentials_dark.svg",
      title: "Tag your Essentials",
      meta: "#{answered} of #{total} tagged",
      progress: {answered, total},
      href: "/me_file_builder?survey_id=#{survey_id}",
      priority: 10,
      return_after_days: 7
    }
  end

  defp essentials(_context), do: nil

  defp tag_goal(%{trait_count: count, tag_goal: goal}) when count < goal do
    %Nudge{
      key: "tag_goal",
      brand: :youdata,
      icon: "hero-tag",
      graphic: "/images/nudges/tag_goal.svg",
      graphic_dark: "/images/nudges/tag_goal_dark.svg",
      title: "Reach #{goal} tags",
      meta: "#{count} of #{goal} for better offers",
      progress: {count, goal},
      href: "/me_file_builder",
      priority: 20,
      return_after_days: 7
    }
  end

  defp tag_goal(_context), do: nil

  defp notifications(%{notifications_on?: false}) do
    %Nudge{
      key: "notifications",
      brand: :sponster,
      icon: "hero-bell",
      graphic: "/images/nudges/notifications.svg",
      title: "Turn on notifications",
      meta: "Know when new ads arrive",
      href: "/settings?setting=notifications",
      priority: 30
    }
  end

  defp notifications(_context), do: nil

  defp invite(_context) do
    %Nudge{
      key: "invite",
      brand: :sponster,
      icon: "hero-user-group",
      graphic: "/images/nudges/invite.svg",
      title: "Invite friends",
      meta: "Earn when they view ads",
      href: "/referrals",
      priority: 40,
      complete_on_tap: true
    }
  end
end
