defmodule QlariusWeb.Api.Admin.CreatorController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.{Creators, Embeds}
  import Ecto.Query
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    creators = Creators.list(params)

    json(conn, %{
      count: length(creators),
      creators: Enum.map(creators, &creator_json(&1, :summary))
    })
  end

  def show(conn, %{"id" => id}) do
    case Creators.fetch(id) do
      {:ok, creator} -> json(conn, %{creator: creator_json(creator, :full)})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create(conn, params) do
    case Creators.create(conn.assigns.current_scope, params, dry_run: Responder.dry_run?(params)) do
      {:ok, %{result: "created"} = result} -> conn |> put_status(201) |> json(body(result))
      {:ok, result} -> json(conn, body(result))
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, creator} <- Creators.fetch(id),
         {:ok, result} <-
           Creators.update(conn.assigns.current_scope, creator, params,
             dry_run: Responder.dry_run?(params)
           ) do
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def embeds(conn, %{"id" => id}) do
    case Creators.fetch(id) do
      {:ok, creator} -> json(conn, %{embeds: Embeds.for_creator(creator)})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp body(%{result: result, record: creator, differences: differences}) do
    %{
      result: result,
      matched: result not in ~w(created would_create),
      creator: creator_json(creator, :full),
      differences: differences
    }
  end

  def creator_json(creator, :summary) do
    %{
      id: creator.id,
      api_ref: creator.api_ref,
      name: creator.name,
      recipient: recipient_json(primary_recipient(creator)),
      recipients: Enum.map(recipients_of(creator), &recipient_json/1),
      catalogs:
        Enum.map(loaded_list(creator.catalogs), fn catalog ->
          %{
            id: catalog.id,
            api_ref: catalog.api_ref,
            name: catalog.name,
            type: catalog.type,
            group_type: catalog.group_type,
            piece_type: catalog.piece_type,
            recipient_id: catalog.recipient_id
          }
        end)
    }
  end

  def creator_json(creator, :full) do
    creator
    |> creator_json(:summary)
    |> Map.merge(%{
      bio: creator.bio,
      image: creator.image,
      is_verified: creator.is_verified
    })
  end

  defp recipient_json(nil), do: nil

  defp recipient_json(recipient) do
    %{
      id: recipient.id,
      api_ref: recipient.api_ref,
      name: recipient.name,
      description: recipient.description,
      message: recipient.message,
      site_url: recipient.site_url,
      split_code: recipient.split_code,
      referral_code: recipient.referral_code,
      recipient_type_id: recipient.recipient_type_id,
      is_primary: recipient.is_primary,
      creator_id: recipient.creator_id,
      user_id: recipient.user_id,
      approval_date: recipient.approval_date
    }
  end

  defp primary_recipient(creator) do
    case recipients_of(creator) do
      [] ->
        loaded(creator.recipient)

      recipients ->
        Enum.find(recipients, & &1.is_primary) || loaded(creator.recipient) || hd(recipients)
    end
  end

  defp recipients_of(%{id: nil, recipient: recipient}) when not is_nil(recipient), do: [recipient]

  defp recipients_of(creator) do
    case Map.get(creator, :recipients) do
      %Ecto.Association.NotLoaded{} ->
        Qlarius.Repo.all(
          from r in Qlarius.Sponster.Recipient,
            where: r.creator_id == ^creator.id,
            order_by: [desc: r.is_primary, asc: r.name]
        )

      recipients when is_list(recipients) ->
        recipients

      _ ->
        []
    end
  end

  defp loaded(%Ecto.Association.NotLoaded{}), do: nil
  defp loaded(value), do: value

  defp loaded_list(%Ecto.Association.NotLoaded{}), do: []
  defp loaded_list(value), do: value
end
