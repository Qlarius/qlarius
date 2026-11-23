defmodule Qlarius.Sponster.Ads.PublisherCredit do
  @moduledoc false

  # A hosted recipient is paid from Sponster's keep whenever one is present.
  # The reader's split only moves part of the reader's collect to the recipient.
  # Native tip-only pages pass no host (`host/2`, `host_from_jump/2`).
  def apply(attrs, nil, _split, _credit, _reader_share), do: attrs

  def apply(attrs, recipient, split, %Decimal{} = credit, reader_share) do
    credited =
      Map.merge(attrs, %{
        recipient_id: recipient.id,
        event_split_code: recipient.split_code,
        event_recipient_split_pct: split_pct(split),
        event_sponster_collect_amt: Decimal.sub(attrs.event_sponster_collect_amt, credit),
        event_sponster_to_recipient_amt: credit
      })

    if reader_share?(reader_share) do
      Map.merge(credited, %{
        event_recipient_collect_amt: reader_share,
        event_me_file_collect_amt: Decimal.sub(attrs.event_me_file_collect_amt, reader_share)
      })
    else
      credited
    end
  end

  def share_of(_amount, split) when not is_integer(split) or split <= 0, do: nil

  def share_of(%Decimal{} = amount, split) do
    amount
    |> Decimal.mult(Decimal.div(Decimal.new(split), Decimal.new(100)))
    |> Decimal.round(2, :half_up)
  end

  def split_pct(amount) when is_integer(amount) and amount > 0, do: amount
  def split_pct(_), do: 0

  @doc """
  Recipient to attach to a banner or video event.

  Hosted pages pass the page recipient. Native tip-only pages pass
  `tip_only?: true` and get no host, so they earn no fixed credit.
  """
  def host(nil, _opts), do: nil

  def host(recipient, opts) do
    if Keyword.get(opts, :tip_only?, false), do: nil, else: recipient
  end

  @doc """
  Recipient to attach to a jump event.

  `autosplit=0` is a native visit. A reader who set their split to 0% does
  not send that flag, so the hosted recipient is still credited.
  """
  def host_from_jump(_recipient, %{"autosplit" => "0"}), do: nil
  def host_from_jump(recipient, _params), do: recipient

  defp reader_share?(nil), do: false
  defp reader_share?(%Decimal{} = amount), do: not Decimal.equal?(amount, 0)
  defp reader_share?(_), do: false
end
