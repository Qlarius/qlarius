defmodule QlariusWeb.Api.Admin.PromoSequenceControllerTest do
  use QlariusWeb.ConnCase, async: false

  alias Qlarius.Accounts.{AdminApiTokens, User}
  alias Qlarius.Repo
  alias Qlarius.Sponster.{PromoSequence, PromoSequences, Recipients}

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    admin =
      %User{}
      |> User.registration_changeset(%{
        "alias" => "promo-api-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Repo.insert!()

    {:ok, _token, raw} = AdminApiTokens.issue(admin, "test")
    %{token: raw, admin: admin}
  end

  defp authed(token), do: build_conn() |> put_req_header("authorization", "Bearer #{token}")

  test "the guide describes sequences", %{token: token} do
    body =
      token
      |> authed()
      |> get(~p"/api/admin/agent_guide?topic=promo_sequences&format=json")
      |> json_response(200)

    assert body["version"] == "2026-11-07.1"
    assert body["guide"] =~ "writes no row and no file"
    assert body["guide"] =~ "Sponster"
    assert Enum.any?(body["endpoints"], &(&1["path"] == "/api/admin/promo_sequences"))
  end

  test "a dry run creates nothing", %{token: token} do
    before = Repo.aggregate(PromoSequence, :count)
    ref = "promo-#{System.unique_integer([:positive])}"

    body =
      token
      |> authed()
      |> post(~p"/api/admin/promo_sequences", %{
        api_ref: ref,
        name: "Summer",
        dry_run: true
      })
      |> json_response(200)

    assert body["result"] == "would_create"
    assert body["promo_sequence"]["name"] == "Summer"
    assert Repo.aggregate(PromoSequence, :count) == before
    refute Repo.get_by(PromoSequence, api_ref: ref)
  end

  test "creates a sequence, adds a slide, and a dry run stores no file", %{token: token} do
    ref = "promo-#{System.unique_integer([:positive])}"

    created =
      token
      |> authed()
      |> post(~p"/api/admin/promo_sequences", %{api_ref: ref, name: "Summer", max_height: 96})
      |> json_response(201)

    assert created["result"] == "created"
    id = created["promo_sequence"]["id"]
    assert created["promo_sequence"]["max_height"] == 96

    upload = png_upload("summer.png")
    before_files = stored_names()

    dry =
      token
      |> authed()
      |> post(~p"/api/admin/promo_sequences/#{id}/slides", %{
        track: "wide",
        image: upload,
        dry_run: true
      })
      |> json_response(200)

    assert dry["result"] == "would_add"
    assert dry["track"] == "wide"
    assert stored_names() == before_files

    added =
      token
      |> authed()
      |> post(~p"/api/admin/promo_sequences/#{id}/slides", %{
        track: "wide",
        image: png_upload("summer.png")
      })
      |> json_response(201)

    assert added["result"] == "added"
    assert added["slide"]["image"] =~ ~r/^summer-[0-9a-f]{8}\.png$/
    File.rm(Path.join(storage_dir(), added["slide"]["image"]))

    shown =
      token
      |> authed()
      |> get(~p"/api/admin/promo_sequences/#{id}")
      |> json_response(200)

    assert shown["promo_sequence"]["slides"] |> Enum.map(& &1["track"]) == ["wide"]
  end

  test "reorders a track and can assign then clear the sequence on a recipient", %{
    token: token,
    admin: admin
  } do
    {:ok, sequence} =
      PromoSequences.create_sequence(%{"name" => "Reorder", "api_ref" => nil, "max_height" => 80})

    {:ok, first} =
      PromoSequences.add_slide(sequence, %{"track" => "narrow", "image" => "one.png"})

    {:ok, second} =
      PromoSequences.add_slide(sequence, %{"track" => "narrow", "image" => "two.png"})

    body =
      token
      |> authed()
      |> post(~p"/api/admin/promo_sequences/#{sequence.id}/slides/reorder", %{
        track: "narrow",
        slide_ids: [second.id, first.id]
      })
      |> json_response(200)

    assert body["result"] == "reordered"

    positions =
      body["promo_sequence"]["slides"]
      |> Enum.filter(&(&1["track"] == "narrow"))
      |> Enum.map(&{&1["image"], &1["position"]})

    assert positions == [{"two.png", 1}, {"one.png", 2}]

    {:ok, recipient} =
      Recipients.create_recipient(%{
        "user_id" => admin.id,
        "name" => "Assign Host",
        "site_url" => "https://assign.example",
        "recipient_type_id" => 1,
        "split_code" => Ecto.UUID.generate(),
        "target_amount" => "0.00"
      })

    assigned =
      token
      |> authed()
      |> patch(~p"/api/admin/recipients/#{recipient.id}", %{promo_sequence_id: sequence.id})
      |> json_response(200)

    assert assigned["recipient"]["promo_sequence_id"] == sequence.id

    cleared =
      token
      |> authed()
      |> patch(~p"/api/admin/recipients/#{recipient.id}", %{promo_sequence_id: nil})
      |> json_response(200)

    assert cleared["recipient"]["promo_sequence_id"] == nil
  end

  defp png_upload(filename) do
    path = Path.join(System.tmp_dir!(), "promo-api-#{System.unique_integer([:positive])}.png")
    File.write!(path, @png)
    %Plug.Upload{path: path, filename: filename, content_type: "image/png"}
  end

  defp storage_dir, do: Path.join([File.cwd!(), "priv/static/uploads/promo_sequences"])

  defp stored_names do
    case File.ls(storage_dir()) do
      {:ok, names} -> Enum.sort(names)
      _ -> []
    end
  end
end
