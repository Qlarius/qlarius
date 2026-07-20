defmodule QlariusWeb.Admin.RecipientHTML do
  use QlariusWeb, :html

  import QlariusWeb.CoreComponents
  alias Qlarius.Qlink.Urls
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  embed_templates "recipient_html/*"

  @doc """
  Copy/paste HTML for third-party sites. Loads the Sponster tipjar widget
  script, which injects a full-function bottom iframe (`/widgets/ads_ext/:split_code`).
  """
  def sponster_embed_code(%{split_code: split_code}) when is_binary(split_code) do
    script_src = Urls.public_app_url("/sponster-tipjar-widget-ext-script.js")

    """
    <div id="sponster-tipjar-widget" sponster-split-code="#{split_code}"></div>
    <script src="#{script_src}"></script>
    """
    |> String.trim()
  end

  def sponster_widget_preview_url(%{split_code: split_code}) when is_binary(split_code) do
    Urls.public_app_url("/widgets/ads_ext/#{URI.encode(split_code)}")
  end
end
