defmodule Qlarius.Sponster.PromoSequencesTest do
  use Qlarius.DataCase, async: false

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.Sponster.{PromoSequence, PromoSequences, Recipients}

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  test "the seed is the current banners, on both tracks, and is the default" do
    sequence = Repo.get_by!(PromoSequence, api_ref: "sponster") |> Repo.preload(:slides)

    assert sequence.name == "Sponster"
    assert sequence.global
    assert sequence.is_default
    assert sequence.max_height == 80
    assert sequence.bounce_image == nil

    for track <- ["wide", "narrow"] do
      images =
        sequence.slides
        |> Enum.filter(&(&1.track == track))
        |> Enum.sort_by(& &1.position)
        |> Enum.map(& &1.image)

      assert images == [
               "uploads/recruiter_banners/DontReadThis_640.png",
               "uploads/recruiter_banners/LifeSponsored_640.png",
               "uploads/recruiter_banners/SellYourAttention_640.png"
             ]
    end
  end

  test "a new recipient copies the current default, and a later edit does not fill a blank one" do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "promo-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    {:ok, recipient} =
      Recipients.create_recipient(%{
        "user_id" => user.id,
        "name" => "Promo Host",
        "site_url" => "https://promo.example",
        "recipient_type_id" => 1,
        "split_code" => Ecto.UUID.generate(),
        "target_amount" => "0.00"
      })

    assert recipient.promo_sequence_id == PromoSequences.default_id()

    recipient =
      recipient
      |> Ecto.Changeset.change(%{promo_sequence_id: nil})
      |> Repo.update!()

    {:ok, recipient} = Recipients.update_recipient(recipient, %{"name" => "Promo Host Updated"})
    assert recipient.promo_sequence_id == nil
    assert recipient.name == "Promo Host Updated"
  end

  test "an empty track keeps the built-in banners" do
    {:ok, sequence} = PromoSequences.create_sequence(%{"name" => "Empty", "max_height" => 90})
    promo = PromoSequences.presentation(%{promo_sequence: sequence})

    assert promo.wide == PromoSequences.fallback_slides()
    assert promo.narrow == PromoSequences.fallback_slides()
    assert promo.max_height == 90
    assert promo.bounce_url == nil
  end

  test "png and svg are stored with a unique suffix and are not resized" do
    png = upload("summer.png", "image/png", @png)
    assert {:ok, filename} = PromoSequences.store_upload(png)
    assert filename =~ ~r/^summer-[0-9a-f]{8}\.png$/

    stored = Path.join([File.cwd!(), "priv/static/uploads/promo_sequences", filename])
    assert File.read!(stored) == @png
    File.rm!(stored)

    svg = ~s(<svg xmlns="http://www.w3.org/2000/svg" width="4" height="4"></svg>)
    assert {:ok, svg_name} = PromoSequences.store_upload(upload("mark.svg", "image/svg+xml", svg))
    assert svg_name =~ ~r/^mark-[0-9a-f]{8}\.svg$/
    svg_path = Path.join([File.cwd!(), "priv/static/uploads/promo_sequences", svg_name])
    assert File.read!(svg_path) =~ "<svg"
    File.rm!(svg_path)

    assert {:error, {:upload_failed, :image, _}} =
             PromoSequences.store_upload(upload("photo.jpg", "image/jpeg", @png))
  end

  defp upload(filename, content_type, body) do
    path =
      Path.join(System.tmp_dir!(), "promo-test-#{System.unique_integer([:positive])}-#{filename}")

    File.write!(path, body)
    %Plug.Upload{path: path, filename: filename, content_type: content_type}
  end
end
