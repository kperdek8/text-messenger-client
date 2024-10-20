defmodule TextMessengerClientWeb.HomePage do
  use TextMessengerClientWeb, :live_view

  def mount(_params, _session, socket) do
    messages = [
      {"Uzytkownik2", "Wiadomosc3"},
      {"Uzytkownik1", "Wiadomosc2"},
      {"Uzytkownik1", "Wiadomosc1"}
    ]

    {:ok, assign(socket, messages: messages)}
  end

  def render(assigns) do
    ~H"""
    <div id="main" class="w-screen h-screen flex bg-black gap-4 p-2">
      <div id="contacts" class="w-1/3 h-full bg-gray-900 p-2 border-gray-700 rounded-lg"></div>
      <div id="chat" class="flex flex-col grow h-full border-gray-700">
        <div id="chat_messages" class="flex flex-col-reverse w-full h-full overflow-y-auto bg-gray-900 p-2 rounded-lg">
          <%= for {user, message} <- @messages do %>
              <.live_component module={TextMessengerClientWeb.ChatMessageComponent} id={message} message={message} user={user} />
          <% end %>
        </div>
        <div id="inputbox" class="flex p-2">
          <form phx-submit="send_message" class="flex w-full">
            <input
              name="message"
              type="text"
              placeholder="Type your message..."
              class="flex-1 p-2 border border-gray-700 bg-gray-800 text-gray-200 rounded-lg focus:outline-none"
            />
            <button type="submit" class="ml-2 p-2 bg-blue-500 text-white rounded-lg">Send</button>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    socket = assign(socket, messages: [{"debug", message} | socket.assigns.messages])
    {:noreply, socket}
  end
end
