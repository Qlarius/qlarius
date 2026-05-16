defmodule Qlarius.Cloudflare.Cache do
  @moduledoc """
  Thin wrapper around the Cloudflare API's cache purge endpoint.

  The vanity share host (qlinkin.bio) is intended to be aggressively
  edge-cached via Cloudflare Page Rules — Qlink pages barely change,
  and the majority of traffic is anonymous shares. When a creator
  updates their Qlink page (title, bio, sections, CTAs), we need to
  invalidate the cached HTML for that specific URL so their next
  visitor sees the fresh version without having to wait for the edge
  TTL to expire.

  ## Configuration

  Expects the following config (typically from env in `runtime.exs`):

      config :qlarius, Qlarius.Cloudflare.Cache,
        zone_id: System.get_env("CLOUDFLARE_QLINKIN_BIO_ZONE_ID"),
        api_token: System.get_env("CLOUDFLARE_API_TOKEN")

  Both values are required. If either is missing the module logs a
  warning and becomes a no-op so dev/test don't fail — cache purges
  are a best-effort optimization, not a correctness requirement.

  ## Usage

      iex> Qlarius.Cloudflare.Cache.purge_url("https://qlinkin.bio/@trae")
      :ok

  Typically called from the Qlink page editor's save callback. See
  `QlariusWeb.Creators.QlinkPageLive.Form`.
  """

  require Logger

  @cloudflare_api "https://api.cloudflare.com/client/v4"

  @doc """
  Purge a single URL from the Cloudflare edge cache. Returns `:ok` on
  success (including no-op when config is missing), or `{:error, reason}`
  when the API call fails. Callers should generally not block on the
  result — this is a best-effort cache busting call and should be wrapped
  in `Task.start/1` or similar when latency matters.
  """
  @spec purge_url(String.t()) :: :ok | {:error, term()}
  def purge_url(url) when is_binary(url) do
    case config() do
      {:ok, zone_id, api_token} ->
        do_purge(zone_id, api_token, [url])

      :missing ->
        # Deliberately quiet in dev/test: the Cloudflare API isn't wired
        # up and there's no edge cache to bust. Log at debug so ops can
        # see it if they flip logging on, but don't noise up the console.
        Logger.debug("Cloudflare cache purge skipped (config missing): #{url}")
        :ok
    end
  end

  defp do_purge(zone_id, api_token, urls) do
    endpoint = "#{@cloudflare_api}/zones/#{zone_id}/purge_cache"

    case Req.post(endpoint,
           headers: [
             {"Authorization", "Bearer #{api_token}"},
             {"Content-Type", "application/json"}
           ],
           json: %{files: urls},
           receive_timeout: 5_000,
           retry: false
         ) do
      {:ok, %Req.Response{status: 200, body: %{"success" => true}}} ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("Cloudflare purge failed (status #{status}): #{inspect(body)}")

        {:error, {:http_status, status}}

      {:error, exception} ->
        Logger.warning("Cloudflare purge transport error: #{inspect(exception)}")
        {:error, exception}
    end
  end

  defp config do
    cfg = Application.get_env(:qlarius, __MODULE__, [])
    zone_id = cfg[:zone_id]
    api_token = cfg[:api_token]

    if is_binary(zone_id) and zone_id != "" and is_binary(api_token) and api_token != "" do
      {:ok, zone_id, api_token}
    else
      :missing
    end
  end
end
