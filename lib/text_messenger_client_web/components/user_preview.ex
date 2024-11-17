defmodule TextMessengerClientWeb.UserPreviewComponent do
  use Phoenix.LiveComponent
  alias TextMessengerClient.Protobuf.User

  def update(%{user: %User{} = user}, socket) do
    {:ok, assign(socket, user: user, menu_open: false)}
  end

  def render(assigns) do
    ~H"""
    <div id={"user-preview-#{@user.id}"} class="relative">
      <!-- User Preview -->
      <div
        phx-click="toggle_menu"
        phx-target={@myself}
        class="flex items-center w-full px-2 py-2 transition rounded-lg cursor-pointer active:bg-gray-300/30 hover:bg-gray-200/20">
        <div class="w-10 h-10 bg-gray-400 rounded-full overflow-hidden mr-2">
          <img src="https://preview.redd.it/high-resolution-remakes-of-the-old-default-youtube-avatar-v0-bgwxf7bec4ob1.png?width=2160&format=png&auto=webp&s=2bdfee069c06fd8939b9c2bff2c9917ed04771af" class="object-cover w-full h-full" />
        </div>
        <div class="text-white text-lg">
          <p><%= @user.name %></p>
        </div>
      </div>

      <!-- Dropdown Menu -->
      <div
        :if={@menu_open}
        class="absolute bg-gray-800 text-gray-200 rounded-lg shadow-lg mt-2 p-2 w-48 z-10"
        phx-click-away="close_menu"
        phx-target={@myself}>
        <p class="text-lg font-bold text-white"><%= @user.name %></p>
        <p class="text-sm mt-1"><strong>UUID:</strong> <%= @user.id %></p>
        <button
          phx-click="remove_user"
          phx-value-id={@user.id}
          phx-target={@myself}
          class="mt-4 w-full p-2 bg-red-500 hover:bg-red-600 text-white rounded-lg">
          Remove from Chat
        </button>
      </div>
    </div>
    """
  end

  def handle_event("toggle_menu", _params, socket) do
    menu_open = socket.assigns.menu_open
    {:noreply, assign(socket, menu_open: !menu_open)}
  end

  def handle_event("close_menu", _params, socket) do
    {:noreply, assign(socket, menu_open: false)}
  end

  def handle_event("remove_user", %{"id" => id}, socket) do
    send(self(), {:kick_user, id}) # Notify the parent LiveView
    {:noreply, assign(socket, menu_open: false)}
  end
end
