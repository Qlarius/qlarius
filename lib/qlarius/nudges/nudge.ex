defmodule Qlarius.Nudges.Nudge do
  @moduledoc """
  A suggested next step, ready to render.

  `graphic` is a path under `priv/static`, shown in place of the brand icon
  chip; `graphic_dark` replaces it in dark mode. `progress` is
  `{current, goal}` and draws a thin bar. `return_after_days` is how long a
  dismissal lasts; nil keeps it dismissed. `complete_on_tap` finishes the
  nudge when it is opened, for steps that have no data to check.
  """

  @enforce_keys [:key, :brand, :title, :href]
  defstruct [
    :key,
    :brand,
    :title,
    :meta,
    :href,
    :progress,
    :graphic,
    :graphic_dark,
    :return_after_days,
    icon: "hero-sparkles",
    priority: 100,
    complete_on_tap: false
  ]

  @type brand :: :youdata | :sponster | :tiqit

  @type t :: %__MODULE__{
          key: String.t(),
          brand: brand(),
          icon: String.t(),
          title: String.t(),
          meta: String.t() | nil,
          href: String.t(),
          progress: {non_neg_integer(), pos_integer()} | nil,
          graphic: String.t() | nil,
          graphic_dark: String.t() | nil,
          priority: integer(),
          return_after_days: pos_integer() | nil,
          complete_on_tap: boolean()
        }
end
