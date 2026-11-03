defmodule QlariusWeb.Api.Admin.PromoSequenceController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.PromoSequences
  alias Qlarius.Sponster.PromoSequences, as: Sequences
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    sequences = PromoSequences.list(params)

    json(conn, %{
      count: length(sequences),
      promo_sequences: Enum.map(sequences, &sequence_json/1)
    })
  end

  def show(conn, %{"id" => id}) do
    case PromoSequences.fetch(id) do
      {:ok, sequence} -> json(conn, %{promo_sequence: sequence_json(sequence)})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create(conn, params) do
    case PromoSequences.create(params, dry_run: Responder.dry_run?(params)) do
      {:ok, %{result: "created"} = result} -> conn |> put_status(201) |> json(body(result))
      {:ok, result} -> json(conn, body(result))
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, sequence} <- PromoSequences.fetch(id),
         {:ok, result} <-
           PromoSequences.update(sequence, params, dry_run: Responder.dry_run?(params)) do
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id} = params) do
    with {:ok, sequence} <- PromoSequences.fetch(id),
         {:ok, result} <-
           PromoSequences.delete(sequence, dry_run: Responder.dry_run?(params)) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def add_slide(conn, %{"id" => id} = params) do
    with {:ok, sequence} <- PromoSequences.fetch(id),
         {:ok, result} <-
           PromoSequences.add_slide(sequence, params, dry_run: Responder.dry_run?(params)) do
      status = if result.result == "added", do: 201, else: 200
      conn |> put_status(status) |> json(slide_body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update_slide(conn, %{"id" => id, "slide_id" => slide_id} = params) do
    with {:ok, sequence} <- PromoSequences.fetch(id),
         {:ok, result} <-
           PromoSequences.replace_slide(sequence, slide_id, params,
             dry_run: Responder.dry_run?(params)
           ) do
      json(conn, slide_body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete_slide(conn, %{"id" => id, "slide_id" => slide_id} = params) do
    with {:ok, sequence} <- PromoSequences.fetch(id),
         {:ok, result} <-
           PromoSequences.delete_slide(sequence, slide_id, dry_run: Responder.dry_run?(params)) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def reorder(conn, %{"id" => id} = params) do
    with {:ok, sequence} <- PromoSequences.fetch(id),
         {:ok, result} <-
           PromoSequences.reorder(sequence, params, dry_run: Responder.dry_run?(params)) do
      json(conn, reorder_body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp body(%{result: result, record: sequence, differences: differences}) do
    %{
      result: result,
      matched: result not in ~w(created would_create),
      promo_sequence: sequence_json(sequence),
      differences: differences
    }
  end

  defp slide_body(%{result: result, slide: slide}) do
    %{result: result, slide: slide_json(slide)}
  end

  defp slide_body(%{result: result} = body) do
    Map.take(body, [:result, :track, :position])
    |> Map.new(fn {k, v} -> {k, v} end)
    |> Map.put(:result, result)
  end

  defp reorder_body(%{result: result, record: sequence}) do
    %{result: result, promo_sequence: sequence_json(sequence)}
  end

  defp reorder_body(body), do: body

  def sequence_json(sequence) do
    slides = if Ecto.assoc_loaded?(sequence.slides), do: sequence.slides, else: []

    %{
      id: sequence.id,
      name: sequence.name,
      api_ref: sequence.api_ref,
      global: sequence.global,
      is_default: sequence.is_default,
      max_height: sequence.max_height,
      bounce_image: sequence.bounce_image,
      bounce_image_url: Sequences.image_url(sequence.bounce_image),
      slides: Enum.map(slides, &slide_json/1)
    }
  end

  defp slide_json(slide) do
    %{
      id: slide.id,
      track: slide.track,
      position: slide.position,
      image: slide.image,
      image_url: Sequences.image_url(slide.image)
    }
  end
end
