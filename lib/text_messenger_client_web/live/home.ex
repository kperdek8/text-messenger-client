defmodule TextMessengerClientWeb.HomePage do
  use TextMessengerClientWeb, :live_view
  import TextMessengerClient.ChatsAPI
  import TextMessengerClient.MessagesAPI
  import TextMessengerClient.UsersAPI

  def mount(_params, _session, socket) do
    contacts = fetch_chats().chats
    messages = fetch_messages(1).messages
    users = fetch_users().users
    last_message_id = List.last(messages).id

    {:ok, assign(socket, messages: messages, contacts: contacts, selected_chat: 1, users: users, last_message_id: last_message_id)}
  end

  def render(assigns) do
    ~H"""
    <div id="main" class="w-screen h-screen flex bg-black gap-4 p-2">
      <div id="contacts_box" class="w-1/3 h-full bg-gray-900 p-2 border-gray-700 rounded-lg">
          <div id="contact_list" class="flex flex-col w-full h-full overflow-y-auto bg-gray-900 p-2 rounded-lg">
            <%= for %Chat{id: id, name: name} <- @contacts do %>
              <.live_component module={TextMessengerClientWeb.ContactComponent} id={id} message={"TODO: Zaimplementuj podgląd ostatniej wiadomość"} name={name} selected_chat={@selected_chat} />
            <% end %>
        </div>
      </div>
      <div id="chat" class="flex flex-col grow h-full border-gray-700">
        <div id="chat_messages" class="flex flex-col-reverse w-full h-full overflow-y-auto bg-gray-900 p-2 rounded-lg">
          <%= for %ChatMessage{id: id, content: message, user_id: user_id} <- @messages do %>
              <.live_component module={TextMessengerClientWeb.ChatMessageComponent} id={id} message={message} user={get_user_name(user_id, @users)} />
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
    id = socket.assigns.last_message_id + 1
    socket = assign(socket, messages: [%ChatMessage{id: id, content: message, user_id: 1} | socket.assigns.messages], last_message_id: id)
    {:noreply, socket}
  end

  def handle_event("select_chat", %{"id" => id}, socket) do
    chat_id = String.to_integer(id)
    socket = assign(socket, selected_chat: chat_id, messages: fetch_messages(chat_id).messages)
    {:noreply, socket}
  end

  defp get_user_name(user_id, users) do
    case Enum.find(users, fn user -> user.id == user_id end) do
      %User{name: name} -> name
      nil -> "Unknown" # TODO: Replace with API call to fetch username
    end
  end
end
