defmodule TextMessengerClientWeb.HomePage do
  use TextMessengerClientWeb, :live_view
  import TextMessengerClient.{ChatsAPI, MessagesAPI, UsersAPI}
  alias TextMessengerClient.Protobuf.{ChatMessage, User, Chat}

  #TODO: https://daisyui.com/components/modal/

  def mount(_params, session, socket) do
    token = Map.get(session, "token", nil)
    if token == nil do
      {:ok, socket |> redirect(to: "/login")}
    else
      chats = fetch_chats().chats
      messages = fetch_messages("0f3649a5-64fb-4828-8bd0-21cf27d3f1db").messages
      users = fetch_users().users

      chat_id = "52853901-722c-4ad4-b53a-06d2e2b8416f"
      user_id = "391a04bb-d60d-4c07-b11d-85527e68ccf2"

      {:ok, websocket} = TextMessengerClient.SocketClient.start(user_id, chat_id, self())

      {:ok, assign(socket, websocket: websocket, messages: messages, chats: chats, selected_chat: chat_id, users: users, token: token, show_create_chat_form: false, show_add_user_form: false)}
    end
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

  def handle_event("toggle_create_chat_form", _params, socket) do
    {:noreply, assign(socket, show_create_chat_form: !socket.assigns.show_create_chat_form)}
  end

  def handle_event("toggle_add_user_form", _params, socket) do
    {:noreply, assign(socket, show_add_user_form: !socket.assigns.show_add_user_form)}
  end

  def handle_event("create_chat", %{"chat_name" => chat_name}, socket) do
    IO.inspect("Creating chat with name: #{chat_name}")
    {:noreply, socket}
  end

  def handle_event("add_user", %{"user_uuid" => user_uuid}, socket) do
    IO.inspect("Adding user with UUID: #{user_uuid}")
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
      <!-- Left side -->
      <div id="left_side" class="flex flex-col w-1/5 h-full bg-gray-900 p-2 border-gray-700 rounded-lg">
        <div id="chat_list" class="flex flex-col w-full h-full overflow-y-auto bg-gray-900 p-2 rounded-lg">
          <%= for %Chat{id: id, name: name} <- @chats do %>
            <.live_component module={TextMessengerClientWeb.ChatPreviewComponent} id={id} message={"TODO: Zaimplementuj podgląd ostatniej wiadomość"} name={name} selected_chat={@selected_chat} />
          <% end %>
          <!-- Create New Chat Button (Below Chat List) -->
          <button class="mt-4 p-2 bg-green-500 hover:bg-green-600 text-white rounded-lg w-full" phx-click="toggle_create_chat_form">
            <p>Create New Chat</p>
          </button>

          <!-- Create New Chat Form -->
          <%= if @show_create_chat_form do %>
            <form phx-submit="create_chat" class="flex flex-col gap-4 mt-4">
              <input
                name="chat_name"
                type="text"
                placeholder="Enter chat name"
                class="w-full p-2 bg-gray-700 border border-gray-600 rounded-lg focus:outline-none text-gray-200"
                required
              />
              <button type="submit" class="mt-2 p-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg w-full">
                Create Chat
              </button>
            </form>
          <% end %>
        </div>
        <!-- Current user + Logout -->
        <div id="logout-container" class="flex justify-between w-full text-white">
          <div class="flex flex-col flex-shrink w-full min-w-0">
            <p class="truncate">Logged in as:</p>
            <p class="truncate">DO IMPLEMENTACJI</p>
          </div>
          <button id="logout-button" class="flex-shrink p-2 bg-red-500 hover:bg-red-600 text-white rounded-lg" phx-hook="SubmitLogoutForm">
            Logout
          </button>
          <!-- Hidden logout form -->
          <form id="logout-form" action="/logout" method="post" style="display: none;">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          </form>
        </div>
      </div>
      <!-- Chat Window -->
      <div id="chat" class="flex flex-col grow h-full border-gray-700">
        <div id="chat_messages" class="flex flex-col-reverse w-full h-full overflow-y-auto bg-gray-900 p-2 rounded-lg">
          <%= for %ChatMessage{id: id, content: message, user_id: user_id} <- @messages do %>
            <.live_component module={TextMessengerClientWeb.ChatMessageComponent} id={id} message={message} user={get_user_name(user_id, @users)} />
          <% end %>
        </div>
        <!-- Message Input Box -->
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
      <!-- User List Sidebar -->
      <div id="user_list" class="w-1/6 flex flex-col h-full border-gray-700">
        <div id="chat_members" class="flex flex-col h-full overflow-y-auto bg-gray-900 p-2 rounded-lg">
          <%= for %User{id: id, name: name} <- @users do %>
            <.live_component module={TextMessengerClientWeb.UserPreviewComponent} id={id} username={name} />
          <% end %>
          <!-- Add User to Chat Button (Below User List) -->
          <button class="mt-4 p-2 bg-yellow-500 hover:bg-yellow-600 text-white rounded-lg w-full" phx-click="toggle_add_user_form">
            Add User to Chat
          </button>

          <!-- Add User to Chat Form -->
          <%= if @show_add_user_form do %>
            <form phx-submit="add_user" class="flex flex-col gap-4 mt-4">
              <input
                name="user_uuid"
                type="text"
                placeholder="Enter user UUID"
                class="w-full p-2 bg-gray-700 border border-gray-600 rounded-lg focus:outline-none text-gray-200"
                required
              />
              <button type="submit" class="mt-2 p-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg w-full">
                Add User
              </button>
            </form>
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
