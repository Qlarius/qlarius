defmodule QlariusWeb.AdHTML do
  use QlariusWeb, :html

  attr :offer, :any, required: true

  def jump(assigns) do
    ~H"""
    <div class="max-w-md mx-auto bg-white p-8 flex flex-col items-center justify-center text-center space-y-6">
      <h1 class="text-2xl font-semibold text-gray-700">Leaving the no-tracking safety of Qlarius.</h1>

      <img src={~p"/images/qlarius_logo_squares.png"} width="100" height="71" />

      <p class="text-gray-600">Be careful out there.</p>
    </div>

    <script>
      setTimeout(() => {
        window.location.href = "<%= @offer.media_piece.jump_url %>";
      }, 2000);
    </script>
    """
  end
end
