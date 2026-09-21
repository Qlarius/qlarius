defmodule Mix.Tasks.Qlarius.AdminApiToken do
  @moduledoc """
  Issues an admin catalog API token.

      mix qlarius.admin_api_token --user-id 1 --label daphne

  The raw token is printed once. Store it with the agent; only the hash is kept.
  """

  use Mix.Task

  @shortdoc "Issue an admin catalog API bearer token"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, strict: [user_id: :integer, label: :string])

    user_id = opts[:user_id]
    label = opts[:label] || "agent"

    cond do
      is_nil(user_id) ->
        Mix.raise("Pass --user-id of an admin user")

      true ->
        user = Qlarius.Accounts.get_user!(user_id)

        case Qlarius.Accounts.AdminApiTokens.issue(user, label) do
          {:ok, token, raw} ->
            IO.puts("token_id=#{token.id}")
            IO.puts(raw)

          {:error, :not_admin} ->
            Mix.raise("User #{user_id} is not an admin")

          {:error, changeset} ->
            Mix.raise("Could not issue token: #{inspect(changeset.errors)}")
        end
    end
  end
end
