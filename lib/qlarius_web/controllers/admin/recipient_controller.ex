defmodule QlariusWeb.Admin.RecipientController do
  use QlariusWeb, :controller

  alias Qlarius.Sponster.Recipients
  alias Qlarius.Sponster.Recipient

  def index(conn, _params) do
    recipients = Recipients.list_recipients() |> Enum.sort_by(& &1.id, :desc)
    render(conn, "index.html", recipients: recipients)
  end

  def show(conn, %{"id" => id, "page" => page_param}) do
    recipient = Recipients.get_recipient!(id)
    page = String.to_integer(page_param || "1")
    # Preload the ledger header for this recipient
    ledger_header = Qlarius.Repo.get_by(Qlarius.Wallets.LedgerHeader, recipient_id: recipient.id)

    ledger_entries_page =
      if ledger_header do
        Qlarius.Wallets.Wallets.list_ledger_entries(ledger_header.id, page, 50)
      else
        %{entries: [], page_number: page, page_size: 50, total_entries: 0, total_pages: 1}
      end

    render(conn, "show.html",
      recipient: recipient,
      ledger_header: ledger_header,
      ledger_entries_page: ledger_entries_page
    )
  end

  def show(conn, %{"id" => id}) do
    show(conn, %{"id" => id, "page" => "1"})
  end

  def new(conn, _params) do
    changeset = Recipients.change_recipient(%Recipient{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"recipient" => recipient_params}) do
    case Recipients.create_recipient(recipient_params) do
      {:ok, _recipient} ->
        conn
        |> put_flash(:info, "Recipient created successfully.")
        |> redirect(to: ~p"/admin/recipients")

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    recipient = Recipients.get_recipient!(id)
    changeset = Recipients.change_recipient(recipient)
    render(conn, "edit.html", recipient: recipient, changeset: changeset)
  end

  def update(conn, %{"id" => id, "recipient" => recipient_params}) do
    recipient = Recipients.get_recipient!(id)

    case Recipients.update_recipient(recipient, recipient_params) do
      {:ok, _recipient} ->
        conn
        |> put_flash(:info, "Recipient updated successfully.")
        |> redirect(to: ~p"/admin/recipients")

      {:error, changeset} ->
        render(conn, "edit.html", recipient: recipient, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    recipient = Recipients.get_recipient!(id)
    {:ok, _recipient} = Recipients.delete_recipient(recipient)

    conn
    |> put_flash(:info, "Recipient deleted successfully.")
    |> redirect(to: ~p"/admin/recipients")
  end
end
