defmodule QlariusWeb.Api.Admin.MediaSequenceController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.MediaSequences
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    sequences = MediaSequences.list(params)

    json(conn, %{count: length(sequences), media_sequences: Enum.map(sequences, &sequence_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case MediaSequences.fetch(id) do
      {:ok, sequence} -> json(conn, %{media_sequence: sequence_json(sequence)})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create(conn, params) do
    case MediaSequences.create(params, dry_run: Responder.dry_run?(params)) do
      {:ok, %{result: "created"} = result} -> conn |> put_status(201) |> json(body(result))
      {:ok, result} -> json(conn, body(result))
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id} = params) do
    with {:ok, sequence} <- MediaSequences.fetch(id),
         {:ok, result} <- MediaSequences.delete(sequence, dry_run: Responder.dry_run?(params)) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp body(result) do
    %{
      result: result.result,
      matched: result.result not in ~w(created would_create),
      defaults_used: Map.get(result, :defaults_used, []),
      media_sequence: sequence_json(result.record),
      differences: Map.get(result, :differences, %{})
    }
  end

  defp sequence_json(sequence) do
    runs =
      case Map.get(sequence, :media_runs) do
        %Ecto.Association.NotLoaded{} -> []
        nil -> []
        runs -> runs
      end

    %{
      id: sequence.id,
      api_ref: sequence.api_ref,
      title: sequence.title,
      description: sequence.description,
      marketer_id: sequence.marketer_id,
      runs:
        Enum.map(runs, fn run ->
          Map.take(run, [
            :id,
            :media_piece_id,
            :frequency,
            :frequency_buffer_hours,
            :maximum_banner_count,
            :banner_retry_buffer_hours
          ])
        end)
    }
  end
end
