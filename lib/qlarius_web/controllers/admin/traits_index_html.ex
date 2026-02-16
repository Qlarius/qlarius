defmodule QlariusWeb.Admin.TraitsIndexHTML do
  use QlariusWeb, :html

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  embed_templates "traits_index_html/*"
end
