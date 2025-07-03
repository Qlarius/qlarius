defmodule QlariusWeb.Admin.RecipientHTML do
  use QlariusWeb, :html

  import QlariusWeb.CoreComponents

  embed_templates "recipient_html/*"

  def recipient_form(assigns) do
    ~H"""
    <.form :let={f} for={@changeset} action={@action} method={@method} class="space-y-4">
      <.input field={f[:name]} label="Name" class="input input-bordered w-full" />
      <.input field={f[:split_code]} label="Split Code" class="input input-bordered w-full" />
      <.input field={f[:recipient_type_id]} label="Recipient Type ID" type="number" class="input input-bordered w-full" />
      <.input field={f[:contact_email]} label="Contact Email" type="email" class="input input-bordered w-full" />
      <div>
        <.button class="btn btn-primary">
          <%= @submit_label || "Save Recipient" %>
        </.button>
        <.link navigate={~p"/admin/recipients"} class="btn ml-2">Cancel</.link>
      </div>
    </.form>
    """
  end
end
