defmodule TextMessengerClientWeb.UserPreviewComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    IO.inspect(assigns)
    ~H"""
    <div class="flex items-start w-full px-2 py-2 transition rounded-lg cursor-pointer active:bg-gray-300/30 hover:bg-gray-200/20 items-center">
      <div class="w-10 h-10 bg-gray-400 rounded-full overflow-hidden mr-2">
        <img src="https://preview.redd.it/high-resolution-remakes-of-the-old-default-youtube-avatar-v0-bgwxf7bec4ob1.png?width=2160&format=png&auto=webp&s=2bdfee069c06fd8939b9c2bff2c9917ed04771af" class="object-cover w-full h-full" />
      </div>
      <div class="text-white text-lg text-top align-middle">
        <p><%= @username %></p>
      </div>
    </div>
    """
  end
end
