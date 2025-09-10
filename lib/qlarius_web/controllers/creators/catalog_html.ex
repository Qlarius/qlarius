defmodule QlariusWeb.Creators.CatalogHTML do
  use QlariusWeb, :html

  import QlariusWeb.CoreComponents
  alias QlariusWeb.TiqitClassHTML

  embed_templates "catalog_html/*"
end
