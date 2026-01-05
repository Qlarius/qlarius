defmodule QlariusWeb.Admin.RecipientHTML do
  use QlariusWeb, :html

  import QlariusWeb.CoreComponents
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  embed_templates "recipient_html/*"
end
