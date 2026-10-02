defmodule QlariusWeb.Admin.RecipientHTML do
  use QlariusWeb, :html

  import QlariusWeb.CoreComponents
  import QlariusWeb.Components.MarketerUI
  alias Qlarius.Qlink.Urls
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias QlariusWeb.Uploaders.RecipientBrandImage

  embed_templates "recipient_html/*"

  @doc """
  Copy/paste HTML for third-party sites. Loads the Sponster tipjar widget
  script, which injects a full-function bottom iframe (`/widgets/ads_ext/:split_code`).

  Script URL follows the page hostname (localhost → local Phoenix, otherwise
  production) so the same snippet works for local demosite testing and live
  publisher pages.
  """
  def sponster_embed_code(%{split_code: split_code}) when is_binary(split_code) do
    """
    <div id="sponster-tipjar-widget" sponster-split-code="#{split_code}"></div>
    <script>
      (function () {
        var host = window.location.hostname;
        var base = (host === "localhost" || host === "127.0.0.1")
          ? "https://localhost:4001"
          : "https://qadabra.app";
        document.write('<script src="' + base + '/sponster-tipjar-widget-ext-script.js"><\\/script>');
      })();
    </script>
    """
    |> String.trim()
  end

  def sponster_widget_preview_url(%{split_code: split_code}) when is_binary(split_code) do
    Urls.public_app_url("/widgets/ads_ext/#{URI.encode(split_code)}")
  end

  defp brand_image_url(recipient) do
    RecipientBrandImage.url({recipient.graphic_url, recipient}, :original)
  end

  defp chicago_now_label do
    case DateTime.shift_zone(DateTime.utc_now(), "America/Chicago") do
      {:ok, chicago_time} -> Calendar.strftime(chicago_time, "%Y-%m-%d %-I:%M %p CST")
      {:error, _} -> Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %-I:%M %p UTC")
    end
  end
end
