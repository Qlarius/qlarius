defmodule Qlarius.Tiqit.Arcade.PublicPage do
  @moduledoc """
  Loads content for the public self-contained Tiqit Arqade page.
  """

  alias Qlarius.Creators.RecipientProvisioning
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.ContentGroup

  @type page :: %{
          group: any(),
          creator: any(),
          recipient: any() | nil,
          tipping_enabled?: boolean(),
          selected_piece_id: integer() | nil
        }

  @doc """
  Loads a published content group and optional selected piece id for the public page.
  """
  @spec load(integer(), keyword()) :: {:ok, page()} | {:error, :not_found}
  def load(content_group_id, opts \\ []) do
    selected_piece_id = Keyword.get(opts, :content_piece_id)

    try do
      group = Arcade.get_content_group!(content_group_id)
      creator = group.catalog.creator
      recipient = load_tipping_recipient(creator, group.id)

      {:ok,
       %{
         group: group,
         creator: creator,
         recipient: recipient,
         tipping_enabled?: not is_nil(recipient),
         selected_piece_id: normalize_piece_id(selected_piece_id, group)
       }}
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
    end
  end

  defp load_tipping_recipient(creator, group_id) do
    site_url = tiqit_arqade_url(group_id)

    case RecipientProvisioning.ensure_recipient_for_creator(creator, site_url: site_url) do
      {:ok, recipient} -> recipient
      {:error, _} -> Repo.preload(creator, :recipient).recipient
    end
  end

  defp tiqit_arqade_url(group_id), do: QlariusWeb.Endpoint.url() <> "/tiqit/arqade/#{group_id}"

  defp normalize_piece_id(nil, _group), do: nil

  defp normalize_piece_id(id, group) when is_integer(id) do
    active_ids =
      group
      |> Map.get(:content_pieces, [])
      |> ContentGroup.active_content_pieces()
      |> Enum.map(& &1.id)

    if id in active_ids, do: id, else: nil
  end

  defp normalize_piece_id(id, group) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> normalize_piece_id(n, group)
      _ -> nil
    end
  end
end
