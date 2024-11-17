defmodule TextMessengerClientWeb.HomePage do
  use TextMessengerClientWeb, :live_view
  alias TextMessengerClient.{ChatsAPI, MessagesAPI, UsersAPI}
  alias TextMessengerClient.Protobuf.{ChatMessage, ChatMessages, User, Users, Chat, Chats}
  alias TextMessengerClient.Helpers.JWT

  def mount(_params, session, socket) do
    token = Map.get(session, "token", nil)
    if is_nil(token) do
      {:ok, socket |> redirect(to: "/login")}
    else
      with {:ok, socket} <- assign_initial_state(socket, token),
           {:ok, socket} <- extract_logged_in_user_data(socket),
           {:ok, socket} <- connect_to_websocket(socket),
           {:ok, socket} <- fetch_chats(socket),
           {:ok, socket} <- open_first_chat(socket),
           {:ok, socket} <- fetch_messages(socket),
           {:ok, socket} <- fetch_users(socket) do
        {:ok, socket}
      else
        {:redirect, socket} ->
          {:ok, socket}
        _ ->
          IO.inspect("Unexpected error occured")
          {:ok, socket}
      end
    end
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    TextMessengerClient.SocketClient.send_message(socket.assigns.websocket, message)
    {:noreply, socket}
  end

  def handle_event("select_chat", %{"id" => id}, socket) do
    {:ok, new_websocket} = TextMessengerClient.SocketClient.change_chat(socket.assigns.websocket, id)

    with socket <- assign(socket, selected_chat: id, websocket: new_websocket),
         {:ok, socket} <- fetch_messages(socket),
         {:ok, socket} <- fetch_users(socket) do
      {:noreply, socket}
    else
      {:redirect, socket} -> {:noreply, socket}
    end
  end

  def handle_event("toggle_create_chat_modal", _params, socket) do
    socket = assign(socket, show_create_chat_modal: !socket.assigns.show_create_chat_modal, form_error: nil)
    {:noreply, socket}
  end

  def handle_event("toggle_add_user_modal", _params, socket) do
    socket = assign(socket, show_add_user_modal: !socket.assigns.show_add_user_modal, form_error: nil)
    {:noreply, socket}
  end

  def handle_event("create_chat", %{"chat_name" => chat_name}, socket) do
    if String.trim(chat_name) == "" do
      {:noreply, assign(socket, form_error: "Chat name cannot be empty")}
    else
      # Placeholder for actual chat creation logic
      IO.inspect("Creating chat with name: #{chat_name}")
      {:noreply, assign(socket, show_create_chat_modal: false, form_error: nil)}
    end
  end

  def handle_event("add_user", %{"user_uuid" => user_id}, socket) do
    if String.trim(user_id) == "" do
      {:noreply, assign(socket, form_error: "User UUID cannot be empty")}
    else
      TextMessengerClient.SocketClient.add_user(socket.assigns.websocket, user_id)
      {:noreply, assign(socket, show_add_user_modal: false, form_error: nil)}
    end
  end

  def handle_event("leave_chat", _params, %{assigns: %{user_id: user_id, websocket: websocket}} = socket) do
    TextMessengerClient.SocketClient.kick_user(websocket, user_id)
    {:noreply, socket}
  end

  def handle_info({:kick_user, user_id}, socket) do
    TextMessengerClient.SocketClient.kick_user(socket.assigns.websocket, user_id)
    {:noreply, socket}
  end

  def handle_info(%PhoenixClient.Message{event: "new_message", payload: %{"message_id" => id, "content" => content, "user_id" => user_id}}, socket) do
    socket = assign(socket, messages: [%ChatMessage{id: id, content: content, user_id: user_id} | socket.assigns.messages])
    {:noreply, socket}
  end

  def handle_info(%PhoenixClient.Message{event: "add_user", payload: %{"user_id" => user_id}}, socket) do
    case fetch_user(socket, user_id) do
      {:ok, socket} -> {:noreply, socket}
      {:redirect, socket} -> {:noreply, socket}
    end
  end

  def handle_info(%PhoenixClient.Message{event: "kick_user", payload: %{"user_id" => user_id}}, socket) do
    {:ok, socket} = remove_user(socket, user_id)
    {:noreply, socket}
  end

  def handle_info(%PhoenixClient.Message{event: "added_to_chat", payload: %{"chat_id" => chat_id}}, socket) do
    case fetch_chat(socket, chat_id) do
      {:ok, socket} -> {:noreply, socket}
      {:redirect, socket} -> {:noreply, socket}
    end
  end

  def handle_info(%PhoenixClient.Message{event: "removed_from_chat", payload: %{"chat_id" => chat_id}}, socket) do
    {:ok, socket} = remove_chat(socket, chat_id)
    if socket.assigns.selected_chat == chat_id do
      with {:ok, socket} <- open_first_chat(socket),
           {:ok, socket} <- fetch_messages(socket),
           {:ok, socket} <- fetch_users(socket) do
        {:noreply, socket}
      else
        {:redirect, socket} ->
          {:noreply, socket}
        _ ->
          IO.inspect("Unexpected error occured")
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end

  end

  def handle_info(%PhoenixClient.Message{event: "phx_close", payload: _payload}, socket) do
    {:noreply, socket}
  end

  def handle_info(%PhoenixClient.Message{event: "phx_reply"}, socket) do
    {:noreply, socket}
  end

  def handle_info(%PhoenixClient.Message{} = message, socket) do
    IO.inspect(message, label: "Unsupported socket message")
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
  	<div id="main" class="w-screen h-screen flex bg-black gap-4 p-2 relative">
      <!-- Left side -->
      <div id="left_side" class="flex flex-col w-1/5 h-full bg-gray-900 p-2 border-gray-700 rounded-lg">
        <div id="chat_list" class="flex flex-col w-full h-full overflow-y-auto bg-gray-900 p-2 rounded-lg">
          <%= for %Chat{id: id, name: name} <- @chats do %>
            <.live_component module={TextMessengerClientWeb.ChatPreviewComponent} id={id} message={"TODO: Zaimplementuj podgląd ostatniej wiadomość"} name={name} selected_chat={@selected_chat} />
          <% end %>

          <!-- Create New Chat Button (Below Chat List) -->
          <button class="mt-4 p-2 bg-green-500 hover:bg-green-600 text-white rounded-lg w-full" phx-click="toggle_create_chat_modal">
            <p>Create New Chat</p>
          </button>
        </div>

        <!-- Current user + Logout -->
        <div id="logout-container" class="flex justify-between w-full text-white">
          <div class="flex flex-shrink w-full h-full min-w-0 mx-2 items-center">
            <div class="flex flex-col">
              <p class="truncate">Logged in as: <strong><%= @username %></strong></p>
              <p
                class="truncate text-xs max-w-xs overflow-hidden text-ellipsis cursor-pointer"
                title={@user_id}
                id="user-id"
                phx-hook="CopyUUID"
              >
                UUID: <%= @user_id %>
              </p>
            </div>
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
              placeholder={"#{if @selected_chat, do: "Type your message...", else: "Join or create chat to send messages"}"}
              class={"flex-1 p-2 border rounded-lg focus:outline-none #{if @selected_chat, do: "bg-gray-800 text-gray-200", else: "bg-gray-700 text-gray-500 cursor-not-allowed"}"}
              disabled={@selected_chat == nil}
            />
            <button
              type="submit"
              class={"ml-2 p-2 rounded-lg text-white #{if @selected_chat, do: "bg-blue-500", else: "bg-gray-500 cursor-not-allowed"}"}
              disabled={@selected_chat == nil}
            >
              Send
            </button>
          </form>
        </div>
      </div>

      <!-- User List Sidebar -->
      <%= if @selected_chat do %>
        <div id="user_list" class="w-1/6 flex flex-col h-full border-gray-700">
          <div id="chat_members" class="flex flex-col h-full overflow-y-auto bg-gray-900 p-2 rounded-lg">
            <%= for %User{} = user <- @users do %>
              <.live_component module={TextMessengerClientWeb.UserPreviewComponent} id={user.id} user={user} />
            <% end %>
            <!-- Add User to Chat Button -->
            <button class="mt-4 p-2 bg-yellow-500 hover:bg-yellow-600 text-white rounded-lg w-full" phx-click="toggle_add_user_modal">
              Add User to Chat
            </button>
            <!-- Leave chat button -->
            <button class="mt-4 p-2 bg-red-500 hover:bg-red-600 text-white rounded-lg w-full" phx-click="leave_chat">
              Leave chat
            </button>
          </div>
        </div>
      <% end %>

      <!-- Modals -->
      <%= if @show_create_chat_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex justify-center items-center z-50">
          <div class="bg-gray-800 text-gray-200 p-6 rounded-lg shadow-lg w-1/3">
            <h3 class="text-xl font-bold mb-4">Create New Chat</h3>
            <%= if @form_error do %>
              <p class="text-red-500 mb-4"><%= @form_error %></p>
            <% end %>
            <form phx-submit="create_chat" class="flex flex-col gap-4">
              <input
                name="chat_name"
                type="text"
                placeholder="Enter chat name"
                class="p-2 bg-gray-700 border border-gray-600 rounded-lg focus:outline-none text-gray-200"
                required
              />
              <div class="flex justify-end gap-4">
                <button type="button" class="p-2 bg-red-500 hover:bg-red-600 text-white rounded-lg" phx-click="toggle_create_chat_modal">
                  Cancel
                </button>
                <button type="submit" class="p-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg">
                  Create
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%= if @show_add_user_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex justify-center items-center z-50">
          <div class="bg-gray-800 text-gray-200 p-6 rounded-lg shadow-lg w-1/3">
            <h3 class="text-xl font-bold mb-4">Add User to Chat</h3>
            <%= if @form_error do %>
              <p class="text-red-500 mb-4"><%= @form_error %></p>
            <% end %>
            <form phx-submit="add_user" class="flex flex-col gap-4">
              <input
                name="user_uuid"
                type="text"
                placeholder="Enter user UUID"
                class="p-2 bg-gray-700 border border-gray-600 rounded-lg focus:outline-none text-gray-200"
                required
              />
              <div class="flex justify-end gap-4">
                <button type="button" class="p-2 bg-red-500 hover:bg-red-600 text-white rounded-lg" phx-click="toggle_add_user_modal">
                  Cancel
                </button>
                <button type="submit" class="p-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg">
                  Add
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
  """
  end

  defp assign_initial_state(socket, token) do
    {:ok,
     socket
       |> assign(token: token)
       |> assign(show_create_chat_modal: false, show_add_user_modal: false, form_error: nil)}
  end

  defp fetch_chat(%{assigns: %{token: token, chats: chats}} = socket, id) when not is_nil(token) do
    with %Chat{} = chat <- ChatsAPI.fetch_chat(token, id) do
      {:ok, socket |> assign(chats: [chat | chats])}
    else
      {:error, "token_expired"} ->
        {:redirect, socket |> redirect(to: "/login")}
      {:error, reason} ->
        IO.inspect(reason, label: "Unexpected error when fetching chat")
        {:error, socket}
    end
  end

  defp fetch_chat(socket, _id) do
    {:ok, socket}
  end

  defp fetch_chats(%{assigns: %{token: token}} = socket) when not is_nil(token) do
    with %Chats{chats: chats} <- ChatsAPI.fetch_chats(token) do
      {:ok, socket |> assign(chats: chats)}
    else
      {:error, "token_expired"} ->
        {:redirect, socket |> redirect(to: "/login")}
      {:error, reason} ->
        IO.inspect(reason, label: "Unexpected error when fetching chats")
        {:error, socket}
    end
  end

  defp fetch_chats(socket) do
    {:ok, socket}
  end

  defp open_first_chat(socket) when is_map_key(socket.assigns, :chats) do
    first_chat_id =
      socket.assigns.chats
      |> List.first()
      |> case do
           nil -> nil
           chat -> Map.get(chat, :id)
         end

    case first_chat_id do
      nil -> {:ok, socket |> assign(selected_chat: nil)}
      id ->
        {:ok, new_websocket} = TextMessengerClient.SocketClient.change_chat(socket.assigns.websocket, id)
        {:ok, socket |> assign(selected_chat: id, websocket: new_websocket)}
    end
  end

  defp open_first_chat(socket) do
    {:ok, socket}
  end

  defp remove_chat(%{assigns: %{chats: chats}} = socket, id) do
    updated_chats =
      chats
      |> Enum.reject(fn chat -> chat.id == id end)

    {:ok, socket |> assign(chats: updated_chats)}
  end

  defp fetch_user(%{assigns: %{token: token, users: users}} = socket, id) when not is_nil(token) do
    with %User{} = user <- UsersAPI.fetch_user(token, id) do
      {:ok, socket |> assign(users: [user | users])}
    else
      {:error, "token_expired"} ->
        {:redirect, socket |> redirect(to: "/login")}
      _ ->
        IO.inspect("Unexpected error when fetching chats")
        {:error, socket}
    end
  end

  defp fetch_user(socket, _id) do
    {:ok, socket}
  end

  defp fetch_users(%{assigns: %{token: token, selected_chat: id}} = socket) when not is_nil(token) and not is_nil(id) do
    with %Users{users: users} <- UsersAPI.fetch_chat_members(token, id) do
      {:ok, socket |> assign(users: users)}
    else
      {:error, "token_expired"} ->
        {:redirect, socket |> redirect(to: "/login")}
      _ ->
        IO.inspect("Unexpected error when fetching users")
        {:error, socket}
    end
  end

  defp fetch_users(socket) do
    {:ok, socket |> assign(users: [])}
  end

  defp remove_user(%{assigns: %{users: users}} = socket, id) do
    updated_users =
      users
      |> Enum.reject(fn user -> user.id == id end)

    {:ok, socket |> assign(users: updated_users)}
  end

  defp fetch_messages(%{assigns: %{token: token, selected_chat: id}} = socket) when not is_nil(token) and not is_nil(id) do
    with %ChatMessages{messages: messages} <- MessagesAPI.fetch_messages(token, id) do
      {:ok, socket |> assign(messages: messages)}
    else
      {:error, "token_expired"} ->
        {:redirect, socket |> redirect(to: "/login")}
      _ ->
        IO.inspect("Unexpected error when fetching messages")
        {:error, socket}
    end
  end

  defp fetch_messages(socket) do
    {:ok, socket |> assign(messages: [])}
  end

  defp connect_to_websocket(%{assigns: %{token: token}} = socket) do
    {:ok, websocket} = TextMessengerClient.SocketClient.start(token)
    {:ok, socket |> assign(websocket: websocket)}
  end

  defp extract_logged_in_user_data(%{assigns: %{token: token}} = socket) do
    with {:ok, payload} <- JWT.decode_payload(token),
         user_id <- payload["sub"],
         username <- payload["username"] do
      socket =
        socket
        |> assign(username: username)
        |> assign(user_id: user_id)
      {:ok, socket}
    else
      {:error, reason} ->
        IO.inspect(reason, label: "Error while extracting user id from token")
    end
  end

  def terminate(_reason, socket) do
    TextMessengerClient.SocketClient.stop(socket.assigns.websocket)
    :ok
  end
end
