defmodule QlariusWeb.Creators.CatalogHTML do
  use QlariusWeb, :html

  import QlariusWeb.CoreComponents
  import QlariusWeb.TiqitClassHTML, only: [tiqit_classes_table: 1, tiqit_class_duration: 1]

  embed_templates "catalog_html/*"
end
