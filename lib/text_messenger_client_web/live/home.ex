defmodule TextMessengerClientWeb.HomePage do
  use TextMessengerClientWeb, :live_view

  @messages %{
    1 => [
      {"Uzytkownik2", "Wiadomosc 3 z czatu 1"},
      {"Uzytkownik1", "Wiadomosc 2 z czatu 1"},
      {"Uzytkownik1", "Wiadomosc 1 z czatu 1"}
    ],
    2 => [
      {"Uzytkownik2", "Wiadomosc 2 z czatu 2"},
      {"Uzytkownik1", "Wiadomosc 1 z czatu 2"}
    ]
  }

  def mount(_params, _session, socket) do
    contacts = load_contacts()
    messages = load_messages(1)

    {:ok, assign(socket, messages: messages, contacts: contacts, selected_chat: 1)}
  end

  def render(assigns) do
    ~H"""
    <div id="main" class="w-screen h-screen flex bg-black gap-4 p-2">
      <div id="contacts_box" class="w-1/3 h-full bg-gray-900 p-2 border-gray-700 rounded-lg">
          <div id="contact_list" class="flex flex-col w-full h-full overflow-y-auto bg-gray-900 p-2 rounded-lg">
            <%= for {id, name, message} <- @contacts do %>
              <.live_component module={TextMessengerClientWeb.ContactComponent} id={id} message={message} name={name} selected_chat={@selected_chat} />
            <% end %>
        </div>
      </div>
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

  def handle_event("select_chat", %{"id" => id}, socket) do
    chat_id = String.to_integer(id)
    socket = assign(socket, selected_chat: chat_id, messages: load_messages(chat_id))
    {:noreply, socket}
  end

  defp load_contacts() do
    contacts = [
      {1, "Czat 1", "Ostatnia wiadomość"},
      {2, "Czat 2", "Jakaś inna ostatnia wiadomość"}
    ]
  end

  defp load_messages(chat_id) do
    @messages[chat_id]
  end
end
