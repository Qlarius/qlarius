defmodule Qlarius.Sponster.Ads.PublisherCredit do
  @moduledoc false

  # A recipient is paid from Sponster's keep whenever one is present.
  # The reader's split only moves part of the reader's collect to the recipient.
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

  defp reader_share?(nil), do: false
  defp reader_share?(%Decimal{} = amount), do: not Decimal.equal?(amount, 0)
  defp reader_share?(_), do: false
end
