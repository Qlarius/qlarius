defmodule Qlarius.Qai.Session do
  @moduledoc """
  A Qai chat session, fleeting by default.

  `expires_at` is the fleet clock: set to now + the fleeting window on create
  and refreshed on every touch, so an active conversation never expires under
  the user. Preserving nulls `expires_at` and stamps `preserved_at`; fleeting
  again restarts the clock. Expired sessions are hard-deleted (with messages)
  by the hourly sweep - fleeting means gone, not archived.

  Sessions belong to a MeFile (the effective persona at creation), never to a
  user directly, matching how MeCP resolves proxy personas.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Qai.Message
  alias Qlarius.YouData.MeFiles.MeFile

  @title_max_length 120

  @type t :: %__MODULE__{}

  schema "qai_sessions" do
    field :title, :string
    field :expires_at, :utc_datetime
    field :preserved_at, :utc_datetime

    belongs_to :me_file, MeFile
    has_many :messages, Message, foreign_key: :qai_session_id

    timestamps(type: :utc_datetime)
  end

  def title_max_length, do: @title_max_length

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:me_file_id, :title, :expires_at, :preserved_at])
    |> validate_required([:me_file_id])
    |> truncate_title()
    |> foreign_key_constraint(:me_file_id)
  end

  def preserved?(%__MODULE__{expires_at: nil}), do: true
  def preserved?(%__MODULE__{}), do: false

  defp truncate_title(changeset) do
    case get_change(changeset, :title) do
      title when is_binary(title) ->
        put_change(changeset, :title, String.slice(String.trim(title), 0, @title_max_length))

      _ ->
        changeset
    end
  end
end
