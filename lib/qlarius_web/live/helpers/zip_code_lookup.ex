defmodule QlariusWeb.Live.Helpers.ZipCodeLookup do
  alias Qlarius.YouData.Traits

  def handle_zip_lookup(socket, zip_code) do
    zip_code = String.trim(zip_code)

    if String.length(zip_code) == 5 and String.match?(zip_code, ~r/^\d{5}$/) do
      parent_trait_id = socket.assigns.trait_in_edit.id

      case Traits.get_zip_code_trait(parent_trait_id, zip_code) do
        nil ->
          socket
          |> Phoenix.Component.assign(:zip_lookup_input, zip_code)
          |> Phoenix.Component.assign(:zip_lookup_trait, nil)
          |> Phoenix.Component.assign(:zip_lookup_valid, false)
          |> Phoenix.Component.assign(:zip_lookup_error, "Zip code not found in database")

        trait ->
          if trait.meta_2 == "STANDARD" do
            socket
            |> Phoenix.Component.assign(:zip_lookup_input, zip_code)
            |> Phoenix.Component.assign(:zip_lookup_trait, trait)
            |> Phoenix.Component.assign(:zip_lookup_valid, true)
            |> Phoenix.Component.assign(:zip_lookup_error, nil)
          else
            socket
            |> Phoenix.Component.assign(:zip_lookup_input, zip_code)
            |> Phoenix.Component.assign(:zip_lookup_trait, trait)
            |> Phoenix.Component.assign(:zip_lookup_valid, false)
            |> Phoenix.Component.assign(
              :zip_lookup_error,
              "Zip code type '#{trait.meta_2}' is not acceptable. Only STANDARD zip codes are allowed."
            )
          end
      end
    else
      socket
      |> Phoenix.Component.assign(:zip_lookup_input, zip_code)
      |> Phoenix.Component.assign(:zip_lookup_trait, nil)
      |> Phoenix.Component.assign(:zip_lookup_valid, false)
      |> Phoenix.Component.assign(:zip_lookup_error, nil)
    end
  end

  def initialize_zip_lookup_assigns(socket) do
    socket
    |> Phoenix.Component.assign(:zip_lookup_input, "")
    |> Phoenix.Component.assign(:zip_lookup_trait, nil)
    |> Phoenix.Component.assign(:zip_lookup_valid, false)
    |> Phoenix.Component.assign(:zip_lookup_error, nil)
  end
end
