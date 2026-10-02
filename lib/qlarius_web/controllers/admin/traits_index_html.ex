defmodule QlariusWeb.Admin.TraitsIndexHTML do
  use QlariusWeb, :html

  import QlariusWeb.Components.MarketerUI, only: [page: 1, page_header: 1, panel: 1]

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  embed_templates "traits_index_html/*"

  attr :target_id, :string, required: true

  defp copy_json_button(assigns) do
    ~H"""
    <button
      type="button"
      class="btn btn-sm"
      onclick={"navigator.clipboard.writeText(document.getElementById('#{@target_id}').innerText).then(() => { const l = this.querySelector('span'); l.textContent = 'Copied!'; setTimeout(() => { l.textContent = 'Copy JSON'; }, 2000); })"}
    >
      <.icon name="hero-document-duplicate" class="size-4" /> <span>Copy JSON</span>
    </button>
    """
  end
end
