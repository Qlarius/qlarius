defmodule Qlarius.Qlink.LinkInBio.Draft do
  @moduledoc """
  In-memory representation of a parsed link-in-bio page before commit.
  """

  @enforce_keys [:platform, :source_url]
  defstruct platform: :generic,
            source_url: nil,
            suggested_alias: nil,
            title: nil,
            bio_text: nil,
            avatar_url: nil,
            social_links: %{},
            sections: [],
            warnings: []

  @type link :: %{
          title: String.t(),
          url: String.t() | nil,
          thumbnail_url: String.t() | nil,
          include?: boolean()
        }

  @type section :: %{
          title: String.t() | nil,
          description: String.t() | nil,
          links: [link()]
        }

  @type t :: %__MODULE__{
          platform: :linktree | :beacons | :generic,
          source_url: String.t(),
          suggested_alias: String.t() | nil,
          title: String.t() | nil,
          bio_text: String.t() | nil,
          avatar_url: String.t() | nil,
          social_links: map(),
          sections: [section()],
          warnings: [String.t()]
        }

  @doc "Flatten included links across sections (for review UI)."
  def included_links(%__MODULE__{sections: sections}) do
    Enum.flat_map(sections, fn section ->
      Enum.filter(section.links || [], & &1[:include?])
    end)
  end

  @doc "Sanitize a username/slug into a Qlink alias candidate."
  def sanitize_alias(nil), do: nil

  def sanitize_alias(raw) when is_binary(raw) do
    raw
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> nil
      alias_ -> String.slice(alias_, 0, 30)
    end
  end
end
