defmodule QlariusWeb.Admin.UnlaunchedCampaignsLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Sponster.Campaigns
  alias QlariusWeb.Uploaders.{ThreeTapBanner, VideoPoster}

  @impl true
  def mount(_params, _session, socket) do
    campaigns =
      Campaigns.list_unlaunched_campaigns()
      |> Enum.map(&Map.put(&1, :preview_src, preview_src(&1)))

    {:ok,
     socket
     |> assign(:page_title, "Unlaunched campaigns")
     |> assign(:campaigns, campaigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.page>
              <.page_header
                title="Unlaunched campaigns"
                count={length(@campaigns)}
                subtitle="Draft campaigns waiting to launch. Review opens the campaign as that marketer."
              />

              <.panel :if={@campaigns == []}>
                <.empty_state icon="hero-megaphone" title="No unlaunched campaigns">
                  Every campaign has been launched or deactivated.
                </.empty_state>
              </.panel>

              <div :if={@campaigns != []} class="space-y-3">
                <article
                  :for={campaign <- @campaigns}
                  id={"unlaunched-campaign-#{campaign.id}"}
                  class="flex items-center gap-4 rounded-2xl border border-base-300 bg-base-100 p-4"
                >
                  <div class="flex h-20 w-36 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-white">
                    <img
                      :if={campaign.preview_src}
                      src={campaign.preview_src}
                      alt=""
                      class="max-h-full max-w-full object-contain"
                    />
                    <.icon
                      :if={!campaign.preview_src}
                      name="hero-photo"
                      class="size-6 text-base-content/30"
                    />
                  </div>

                  <div class="min-w-0 flex-1">
                    <h2 class="truncate text-base font-semibold">{campaign.title}</h2>
                    <p class="truncate text-sm text-base-content/60">
                      {campaign.marketer.business_name}
                    </p>
                  </div>

                  <.link
                    href={review_path(campaign)}
                    method="post"
                    id={"review-campaign-#{campaign.id}"}
                    class="btn btn-sm btn-primary shrink-0"
                  >
                    Review
                  </.link>
                </article>
              </div>
            </.page>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp review_path(campaign) do
    return_to = "/marketer/campaigns?campaign=#{campaign.id}"
    ~p"/marketer/select/#{campaign.marketer_id}?#{[return_to: return_to]}"
  end

  # The first ad in the sequence: a video's poster, otherwise its banner.
  defp preview_src(campaign) do
    campaign
    |> first_media_piece()
    |> piece_preview_src()
  end

  defp first_media_piece(%{media_sequence: %{media_runs: runs}}) when is_list(runs) do
    runs
    |> Enum.sort_by(&{&1.sequence_start_phase || 1_000_000, &1.id})
    |> List.first()
    |> case do
      %{media_piece: piece} -> piece
      _ -> nil
    end
  end

  defp first_media_piece(_), do: nil

  defp piece_preview_src(%{media_piece_type_id: 2, video_poster_image: image} = piece)
       when is_binary(image) and image != "" do
    VideoPoster.url({image, piece}, :original)
  end

  defp piece_preview_src(%{banner_image: image} = piece) when is_binary(image) and image != "" do
    ThreeTapBanner.url({image, piece}, :original)
  end

  defp piece_preview_src(_), do: nil
end
