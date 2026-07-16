defmodule Qlarius.Qai.Message do
  @moduledoc """
  One turn in a Qai session. `model` records which model class produced an
  assistant message (nil for user turns); `stopped` marks an assistant message
  the user cut off mid-stream, so regenerate and the transcript can show it
  honestly. Content is written once at the end of a stream, not per delta.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Qai.Session

  @roles ~w(user assistant)

  @type t :: %__MODULE__{}

  schema "qai_messages" do
    field :role, :string
    field :content, :string, default: ""
    field :model, :string
    field :stopped, :boolean, default: false
    # Provider token usage, summed across the turn's tool rounds. Feeds the
    # unit-economics livebook; empty for user turns and stopped streams.
    field :usage, :map, default: %{}

    belongs_to :session, Session, foreign_key: :qai_session_id

    timestamps(type: :utc_datetime)
  end

  def roles, do: @roles

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:qai_session_id, :role, :content, :model, :stopped, :usage])
    |> validate_required([:qai_session_id, :role])
    |> validate_inclusion(:role, @roles)
    |> foreign_key_constraint(:qai_session_id)
  end
end
