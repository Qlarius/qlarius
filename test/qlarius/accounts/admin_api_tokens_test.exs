defmodule Qlarius.Accounts.AdminApiTokensTest do
  use Qlarius.DataCase, async: true

  import Ecto.Query

  alias Qlarius.Accounts.{AdminApiToken, AdminApiTokens, User}
  alias Qlarius.Repo

  test "authenticate records last_used_at once a minute" do
    admin =
      %User{}
      |> User.registration_changeset(%{
        "alias" => "token-admin-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Repo.insert!()

    {:ok, _token, raw} = AdminApiTokens.issue(admin, "burst")

    assert {:ok, _user, token} = AdminApiTokens.authenticate(raw)
    touched = Repo.get!(AdminApiToken, token.id).last_used_at
    assert touched

    assert {:ok, _, _} = AdminApiTokens.authenticate(raw)
    assert Repo.get!(AdminApiToken, token.id).last_used_at == touched

    stale = DateTime.add(DateTime.utc_now(), -120, :second) |> DateTime.truncate(:second)

    Repo.update_all(from(t in AdminApiToken, where: t.id == ^token.id),
      set: [last_used_at: stale]
    )

    assert {:ok, _, _} = AdminApiTokens.authenticate(raw)
    assert DateTime.compare(Repo.get!(AdminApiToken, token.id).last_used_at, stale) == :gt
  end
end
