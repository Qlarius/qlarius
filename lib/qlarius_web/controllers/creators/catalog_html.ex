defmodule QlariusWeb.Creators.CatalogHTML do
  use QlariusWeb, :html

  import QlariusWeb.CoreComponents
  import QlariusWeb.TiqitClassHTML, only: [tiqit_class_duration: 1]
  import QlariusWeb.Money, only: [format_usd: 1]

  embed_templates "catalog_html/*"
end
