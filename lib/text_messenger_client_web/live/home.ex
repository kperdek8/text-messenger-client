defmodule TextMessengerClientWeb.HomePage do
  use TextMessengerClientWeb, :live_view
  import TextMessengerClient.{ChatsAPI, MessagesAPI, UsersAPI}
  alias TextMessengerClient.Protobuf.{ChatMessage, User, Chat}

  def mount(_params, _session, socket) do
    chats = fetch_chats().chats
    messages = fetch_messages("0f3649a5-64fb-4828-8bd0-21cf27d3f1db").messages
    users = fetch_users().users

    chat_id = "0f3649a5-64fb-4828-8bd0-21cf27d3f1db"
    user_id = "1a76a11a-195d-486f-be0c-b1aee65e3117"

    {:ok, websocket} = TextMessengerClient.SocketClient.start(user_id, chat_id, self())

    {:ok, assign(socket, websocket: websocket, messages: messages, chats: chats, selected_chat: chat_id, users: users)}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    TextMessengerClient.SocketClient.send_message(socket.assigns.websocket, message)
    {:noreply, socket}
  end

  def handle_event("select_chat", %{"id" => id}, socket) do
    {:ok, new_websocket} = TextMessengerClient.SocketClient.change_chat(socket.assigns.websocket, id)

    socket = assign(socket, websocket: new_websocket, selected_chat: id, messages: fetch_messages(id).messages)
    {:noreply, socket}
  end

  def handle_info(%PhoenixClient.Message{event: "new_message", payload: payload}, socket) do
    socket = assign(socket, messages: [%ChatMessage{id: payload["message_id"], content: payload["content"], user_id: payload["user_id"]} | socket.assigns.messages])
    {:noreply, socket}
  end

  # TODO
  def handle_info(%PhoenixClient.Message{event: "add_user", payload: _payload}, socket) do
    {:noreply, socket}
  end

  def handle_info(%PhoenixClient.Message{event: event}, socket) do
    IO.inspect(event, label: "Unsupported socket event")
    {:noreply, socket}
  end


  defp get_user_name(user_id, users) do
    case Enum.find(users, fn user -> user.id == user_id end) do
      %User{name: name} -> name
      nil -> "Unknown" # TODO: Replace with API call to fetch username
    end
  end

  def render(assigns) do
    ~H"""
    <div id="main" class="w-screen h-screen flex bg-black gap-4 p-2">
      <div id="chat_entries" class="w-1/5 h-full bg-gray-900 p-2 border-gray-700 rounded-lg">
        <div id="chat_list" class="flex flex-col w-full h-full overflow-y-auto bg-gray-900 p-2 rounded-lg">
          <%= for %Chat{id: id, name: name} <- @chats do %>
            <.live_component module={TextMessengerClientWeb.ChatPreviewComponent} id={id} message={"TODO: Zaimplementuj podgląd ostatniej wiadomość"} name={name} selected_chat={@selected_chat} />
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
      <div id="user_list" class="w-1/6 flex flex-col h-full border-gray-700">
        <div id="chat_members" class="flex flex-col h-full overflow-y-auto bg-gray-900 p-2 rounded-lg">
          <%= for %User{id: id, name: name} <- @users do %>
              <.live_component module={TextMessengerClientWeb.UserPreviewComponent} id={id} username={name} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def terminate(_reason, socket) do
    TextMessengerClient.SocketClient.stop(socket.assigns.websocket)
    :ok
  end
end
