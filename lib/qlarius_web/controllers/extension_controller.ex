defmodule QlariusWeb.ExtensionController do
  use QlariusWeb, :controller

  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Sponster.Offers

  def ad_count(conn, _params) do
    me_file = conn.assigns.current_scope.user.me_file

    ads_count = MeFile.ad_offer_count(me_file)
    offered_amount = Offers.total_active_offer_amount(me_file) || Decimal.new(0)

    json(conn, %{
      ads_count: ads_count,
      offered_amount: Decimal.to_float(offered_amount)
    })
  end
end
