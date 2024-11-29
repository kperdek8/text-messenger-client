defmodule TextMessengerClientWeb.HomePage do
  use TextMessengerClientWeb, :live_view
  alias TextMessengerClient.{ChatsAPI, MessagesAPI, UsersAPI, KeysAPI}
  alias TextMessengerClient.Protobuf.{ChatMessage, ChatMessages, User, Users, Chat, Chats, GroupKeys, GroupKey, UserKeysList, UserKeys}
  alias TextMessengerClient.Helpers.{JWT, Crypto}

  require Logger

  @sign_pub_key_path "sign_pub.pem"
  @sign_priv_key_path "sign_priv.pem"
  @enc_pub_key_path "enc_pub.pem"
  @enc_priv_key_path "enc_priv.pem"

  def mount(_params, session, socket) do
    token = Map.get(session, "token", nil)
    if is_nil(token) do
      {:ok, socket |> redirect(to: "/login")}
    else
      with {:ok, socket} <- assign_initial_state(socket, token),
           {:ok, socket} <- extract_logged_in_user_data(socket),
           {:ok, socket} <- connect_to_websocket(socket),
           {:ok, socket} <- read_rsa_keys_from_file(socket, @enc_pub_key_path, @enc_priv_key_path, :encryption),
           {:ok, socket} <- read_rsa_keys_from_file(socket, @sign_pub_key_path, @sign_priv_key_path, :signature),
           {:ok, socket} <- fetch_chats(socket),
           {:ok, socket} <- open_first_chat(socket),
           {:ok, socket} <- fetch_group_keys(socket),
           {:ok, socket} <- fetch_messages(socket),
           {:ok, socket} <- fetch_public_keys(socket),
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
    key = socket.assigns.latest_group_key
    {encrypted_message, iv} = Crypto.encrypt_message(message, key)
    case TextMessengerClient.SocketClient.send_message(socket.assigns.websocket, encrypted_message, iv) do
      :ok -> {:noreply, socket |> assign(key_changed: false, message_input: "")}
      {:change_key, chat_id} ->
        send_new_group_key(socket, chat_id)
        {:noreply, socket |> assign(key_changed: true)}
      {:error, reason} ->
        Logger.warning("Error while sending message #{reason}}")
        {:noreply, socket}
    end
  end

  def handle_event("update_message_input", %{"message" => message}, socket) do
    {:noreply, assign(socket, :message_input, message)}
  end

  def handle_event("select_chat", %{"id" => id}, socket) do
    {:ok, new_websocket} = TextMessengerClient.SocketClient.change_chat(socket.assigns.websocket, id)

    with socket <- assign(socket, selected_chat: id, websocket: new_websocket),
         {:ok, socket} <- fetch_public_keys(socket),
         {:ok, socket} <- fetch_group_keys(socket),
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
      new_chat = ChatsAPI.create_chat(socket.assigns.token, chat_name)
      {:noreply, assign(socket, show_create_chat_modal: false, form_error: nil, chats: [new_chat | socket.assigns.chats])}
    end
  end

  def handle_event("add_user", %{"user_uuid" => user_id}, socket) do
    if String.trim(user_id) == "" do
      {:noreply, assign(socket, form_error: "User UUID cannot be empty")}
    else
      TextMessengerClient.SocketClient.add_user(socket.assigns.websocket, user_id)
      case add_user(socket, user_id) do
        {:ok, socket} ->
          send_new_group_key(socket, socket.assigns.selected_chat)
          {:noreply, socket |> assign(show_add_user_modal: false, form_error: nil)}
        {:redirect, socket} -> {:noreply, socket}
      end
    end
  end

  def handle_event("leave_chat", _params, %{assigns: %{user_id: user_id, websocket: websocket}} = socket) do
    TextMessengerClient.SocketClient.kick_user(websocket, user_id)
    {:noreply, socket}
  end

  def handle_info({:kick_user, user_id}, socket) do
    TextMessengerClient.SocketClient.kick_user(socket.assigns.websocket, user_id)
    {:ok, socket} = remove_user(socket, user_id)
    send_new_group_key(socket, socket.assigns.selected_chat)
    {:noreply, socket}
  end

  def handle_info(%PhoenixClient.Message{event: "new_message", payload: %{"message_id" => id, "content" => encoded_content, "user_id" => user_id, "iv" => encoded_iv}}, socket) do
    Logger.debug("Received `new_message` message from server")
    {:ok, iv} = Base.decode64(encoded_iv)
    {:ok, content} = Base.decode64(encoded_content)
    {:ok, decrypted_content} = Crypto.decrypt_message(content, iv, socket.assigns.latest_group_key)
    socket = assign(socket, messages: [%{id: id, content: content, user_id: user_id, iv: iv, decrypted_content: decrypted_content} | socket.assigns.messages])
    {:noreply, socket}
  end

  def handle_info(%PhoenixClient.Message{event: "change_key_request", payload: %{"chat_id" => chat_id}}, socket) do
    Logger.debug("Received `change_key_request` message from server")
    send_new_group_key(socket, chat_id)
    {:noreply, socket}
  end

  def handle_info(%PhoenixClient.Message{event: "group_key_changed", payload: _payload}, socket) do
    Logger.debug("Received `group_key_changed` message from server")
    case fetch_latest_group_key(socket) do
      {:ok, socket} -> {:noreply, socket}
      {:redirect, socket} -> {:noreply, socket}
      {:error, socket} ->
        Logger.warning("Something went wrong while fetching latest group key")
        {:noreply, socket}
    end
  end

  def handle_info(%PhoenixClient.Message{event: "add_user", payload: %{"user_id" => user_id}}, socket) do
    Logger.debug("Received `add_user` message from server")
      case add_user(socket, user_id) do
        {:ok, socket} -> {:noreply, socket}
        {:redirect, socket} -> {:noreply, socket}
      end
  end

  def handle_info(%PhoenixClient.Message{event: "kick_user", payload: %{"user_id" => user_id}}, socket) do
    Logger.debug("Received `kick_user` message from server")
    {:ok, socket} = remove_user(socket, user_id)
    {:noreply, socket}
  end

  def handle_info(%PhoenixClient.Message{event: "added_to_chat", payload: %{"chat_id" => chat_id}}, socket) do
    Logger.debug("Received `added_to_chat` message from server")
    case fetch_chat(socket, chat_id) do
      {:ok, socket} -> {:noreply, socket}
      {:redirect, socket} -> {:noreply, socket}
    end
  end

  def handle_info(%PhoenixClient.Message{event: "removed_from_chat", payload: %{"chat_id" => chat_id}}, socket) do
    Logger.debug("Received `removed_from_chat` message from server")
    {:ok, socket} = remove_chat(socket, chat_id)
    if socket.assigns.selected_chat == chat_id do
      with {:ok, socket} <- open_first_chat(socket),
         {:ok, socket} <- fetch_public_keys(socket),
         {:ok, socket} <- fetch_group_keys(socket),
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
    Logger.warning("Unsupported socket message #{inspect(message)}")
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
            <div class="flex flex-col min-w-0">
              <p class="truncate overflow-hidden" title={@username}>Logged in as: <strong><%= @username %></strong></p>
              <p
                class="truncate text-xs max-w-xs overflow-hidden cursor-pointer"
                title={@user_id}
                id="user-id"
                phx-hook="CopyUUID"
              >
                UUID: <%= @user_id %>
              </p>
            </div>
          </div>
          <button id="logout-button" class="flex flex-shrink p-2 bg-red-500 hover:bg-red-600 text-white rounded-lg" phx-hook="SubmitLogoutForm">
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
          <%= for %{id: id, decrypted_content: message, user_id: user_id} <- @messages, not is_nil(message) do %>
            <.live_component module={TextMessengerClientWeb.ChatMessageComponent} id={id} message={message} user={get_user_name(user_id, @users)} />
          <% end %>
        </div>

        <!-- Message Input Box -->
        <div class="flex flex-col">
          <%= if @key_changed do %>
            <div class="p-2 mt-2 bg-yellow-300 text-gray-800 text-center rounded-lg border border-yellow-400">
              <p class="font-semibold">Group key has changed in meantime. Please resend your message.</p>
            </div>
          <% end %>
          <div id="inputbox" class="flex py-2">
            <form phx-submit="send_message" class="flex w-full">
              <input
                name="message"
                type="text"
                value={@message_input || ""}
                placeholder={"#{if @selected_chat, do: "Type your message...", else: "Join or create chat to send messages"}"}
                class={"flex-1 p-2 border rounded-lg focus:outline-none #{if @selected_chat, do: "bg-gray-800 text-gray-200", else: "bg-gray-700 text-gray-500 cursor-not-allowed"}"}
                disabled={@selected_chat == nil}
                phx-change="update_message_input"
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
       |> assign(show_create_chat_modal: false, show_add_user_modal: false, form_error: nil, key_changed: false, message_input: "")}
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

  defp add_user(socket, user_id) do
    with {:ok, socket} <- fetch_user(socket, user_id),
         {:ok, socket} <- fetch_user_keys(socket, user_id) do
      {:ok, socket}
    else
      {:redirect, socket} -> {:noreply, socket}
    end
  end

  defp remove_user(%{assigns: %{users: users, public_keys: public_keys}} = socket, id) do
    updated_users =
      users
      |> Enum.reject(fn user -> user.id == id end)

    updated_public_keys =
      public_keys
      |> Map.drop([id])

    {:ok, socket |> assign(users: updated_users, public_keys: updated_public_keys)}
  end

  defp fetch_messages(%{assigns: %{token: token, selected_chat: id, group_keys: group_keys}} = socket) when not is_nil(token) and not is_nil(id) do
    with %ChatMessages{messages: messages} <- MessagesAPI.fetch_messages(token, id) do
      decrypted_messages =
        Enum.map(messages, fn message ->
          decrypted_message = decrypt_message(message, group_keys)
          Map.put(message, :decrypted_content, decrypted_message) # Add decrypted_content to the message struct
        end)

      {:ok, socket |> assign(messages: decrypted_messages)}
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

  defp fetch_group_keys(%{assigns: %{token: token, selected_chat: id, encryption_private_key: encoded_private_key}} = socket)
  when not is_nil(token) and not is_nil(id) and not is_nil(encoded_private_key) do
    private_key = Crypto.decode_key(encoded_private_key, :RSAPrivateKey)
    with %GroupKeys{group_keys: keys} <- KeysAPI.fetch_group_keys(token, id) do
      group_keys =
        Enum.reduce(keys, %{}, fn %GroupKey{key_number: key_number} = group_key, acc ->
          case Crypto.extract_and_decrypt_group_key(group_key, private_key) do
            {:ok, decrypted_key} ->
              Map.put(acc, key_number, decrypted_key)

            {:error, _reason} ->
              Logger.warning("Failed to decrypt group key number #{key_number}")
              acc
          end
        end)

    {latest_group_key, latest_group_key_number} =
      keys
      |> Enum.max_by(& &1.key_number, fn -> nil end)
      |> case do
        nil -> {nil, nil}
        %GroupKey{key_number: key_number} = key ->
          case Crypto.extract_and_decrypt_group_key(key, private_key) do
            {:ok, decrypted_key} ->
              {decrypted_key, key_number}

            {:error, _reason} ->
              Logger.warning("Failed to decrypt latest group key number #{key_number}")
              {nil, nil}
          end
      end

    {:ok, socket |> assign(group_keys: group_keys, latest_group_key: latest_group_key, latest_group_key_number: latest_group_key_number)}
    else
      {:error, "token_expired"} ->
        {:redirect, socket |> redirect(to: "/login")}
      _ ->
        IO.inspect("Unexpected error when fetching group keys")
        {:error, socket}
    end
  end

  defp fetch_group_keys(socket) do
    {:ok, socket |> assign(group_keys: %{}, latest_group_key: nil, latest_group_key_number: nil)}
  end

  defp fetch_latest_group_key(%{assigns: %{token: token, selected_chat: id, encryption_private_key: encoded_private_key,
    group_keys: group_keys, latest_group_key_number: latest_group_key_number}} = socket
   ) do
    private_key = Crypto.decode_key(encoded_private_key, :RSAPrivateKey)
    new_latest_group_key_number =
      case latest_group_key_number do
        nil -> 1
        number -> number + 1
      end

    with %GroupKey{} = group_key <- KeysAPI.fetch_latest_group_key(token, id) do
      case Crypto.extract_and_decrypt_group_key(group_key, private_key) do
        {:ok, decrypted_key} ->
          updated_group_keys = Map.put(group_keys, Integer.to_string(new_latest_group_key_number), decrypted_key)
          {:ok, socket |> assign(group_keys: updated_group_keys, latest_group_key: decrypted_key, latest_group_key_number: latest_group_key_number)}

        {:error, _reason} ->
          Logger.warning("Failed to decrypt latest group key")
          {:error, socket}
      end
    else
      {:error, "token_expired"} ->
        {:redirect, socket |> redirect(to: "/login")}
      _ ->
        Logger.error("Unexpected error when fetching latest group key")
        {:error, socket}
    end
  end

  defp fetch_user_keys(%{assigns: %{token: token, public_keys: keys}} = socket, user_id) when not is_nil(token) and not is_nil(user_id) do
    with %UserKeys{encryption_key: enc_key, signature_key: sig_key} <- KeysAPI.fetch_user_keys(token, user_id) do
      public_keys = Map.put(keys, user_id, %{encryption_key: enc_key, signature_key: sig_key})
    {:ok, socket |> assign(public_keys: public_keys)}
    else
      {:error, "token_expired"} ->
        {:redirect, socket |> redirect(to: "/login")}
      _ ->
        IO.inspect("Unexpected error when fetching user keys")
        {:error, socket}
    end
  end

  defp fetch_user_keys(socket, _user_id) do
    {:ok, socket}
  end

  defp fetch_public_keys(%{assigns: %{token: token, selected_chat: id}} = socket) when not is_nil(token) and not is_nil(id) do
    with %UserKeysList{user_keys: keys} <- KeysAPI.fetch_members_keys(token, id) do
      public_keys =
        keys
        |> Enum.reduce(%{}, fn %UserKeys{user_id: user_id, encryption_key: enc_key, signature_key: sig_key}, acc ->
          Map.put(acc, user_id, %{
            encryption_key: enc_key,
            signature_key: sig_key
          })
        end)
    {:ok, socket |> assign(public_keys: public_keys)}
    else
      {:error, "token_expired"} ->
        {:redirect, socket |> redirect(to: "/login")}
      _ ->
        IO.inspect("Unexpected error when fetching public keys")
        {:error, socket}
    end
  end

  defp fetch_public_keys(socket) do
    {:ok, socket |> assign(signature_keys: %{}, encryption_keys: %{})}
  end

  defp send_new_group_key(socket, chat_id) do
    %{user_id: user_id, public_keys: public_keys, signature_private_key: sign_key} = socket.assigns
    members = Enum.map(public_keys, fn {user_id, keys} ->
      {user_id, keys.encryption_key}
    end)

    group_keys = Crypto.generate_group_keys(members, user_id, sign_key, chat_id)
    TextMessengerClient.SocketClient.send_keys(socket.assigns.websocket, group_keys)
  end

  defp read_rsa_keys_from_file(%{assigns: %{token: token}} = socket, pub_key_path, priv_key_path, :encryption) do
    user_pub_key_path = "#{socket.assigns.username}_#{pub_key_path}"
    user_priv_key_path = "#{socket.assigns.username}_#{priv_key_path}"

    with {:ok, public_key} <- Crypto.read_key_from_file(:RSAPublicKey, user_pub_key_path),
         {:ok, private_key} <- Crypto.read_key_from_file(:RSAPrivateKey, user_priv_key_path) do
      {:ok, socket |> assign(encryption_public_key: public_key, encryption_private_key: private_key)}
    else
      {:error, reason} ->
        IO.inspect("Could not read encryption RSA keys from file: #{reason}. Generating new pair.")
        {public_key, private_key} = generate_rsa_keys(token, user_pub_key_path, user_priv_key_path, :encryption)
        {:ok, socket |> assign(encryption_public_key: public_key, encryption_private_key: private_key)}
    end
  end

  defp read_rsa_keys_from_file(%{assigns: %{token: token}} = socket, pub_key_path, priv_key_path, :signature) do
    user_pub_key_path = "#{socket.assigns.username}_#{pub_key_path}"
    user_priv_key_path = "#{socket.assigns.username}_#{priv_key_path}"

    with {:ok, public_key} <- Crypto.read_key_from_file(:RSAPublicKey, user_pub_key_path),
         {:ok, private_key} <- Crypto.read_key_from_file(:RSAPrivateKey, user_priv_key_path) do
      {:ok, socket |> assign(signature_public_key: public_key, signature_private_key: private_key)}
    else
      {:error, reason} ->
        IO.inspect("Could not read RSA keys from file: #{reason}. Generating new pair.")
        {public_key, private_key} = generate_rsa_keys(token, user_pub_key_path, user_priv_key_path, :signature)
        {:ok, socket |> assign(signature_public_key: public_key, signature_private_key: private_key)}
    end
  end

  defp read_rsa_keys_from_file(socket, _, _, _) do
    IO.inspect("Incorrect usage of 'read_rsa_keys_from_file'. Program may not behave correctly without loaded RSA keys.")
    {:ok, socket |> assign(public_key: nil, private_key: nil)}
  end

  defp generate_rsa_keys(token, pub_key_path, priv_key_path, :encryption) do
    {public_key, private_key} = Crypto.generate_rsa_keys()
    with :ok <- Crypto.write_key_to_file(public_key, :RSAPublicKey, pub_key_path),
         :ok <- Crypto.write_key_to_file(private_key, :RSAPrivateKey, priv_key_path),
         {:ok, _body} <- KeysAPI.post_encryption_key(token, public_key) do
      {public_key, private_key}
    else
      {:error, reason} ->
        IO.inspect("Error while writing new RSA key pair to file #{reason}}.")
    end
  end

  defp generate_rsa_keys(token, pub_key_path, priv_key_path, :signature) do
    {public_key, private_key} = Crypto.generate_rsa_keys()
    with :ok <- Crypto.write_key_to_file(public_key, :RSAPublicKey, pub_key_path),
         :ok <- Crypto.write_key_to_file(private_key, :RSAPrivateKey, priv_key_path),
         {:ok, _body} <- KeysAPI.post_signature_key(token, public_key) do
      {public_key, private_key}
    else
      {:error, reason} ->
        IO.inspect("Error while writing new RSA key pair to file #{reason}}.")
    end
  end

  # Helper function to find specific group key and use it to decrypt message.
  defp decrypt_message(%ChatMessage{key_number: key_number, content: content, iv: iv}, group_keys) do
    case Map.get(group_keys, key_number) do
      nil ->
        Logger.warning("No group key for key_number #{key_number}")
        nil

      key ->
        case Crypto.decrypt_message(content, iv, key) do
          {:ok, decrypted_message} -> decrypted_message
          error ->
            Logger.warning("Failed to decrypt message with key_number #{key_number} #{inspect(error)}}")
            nil
        end
    end
  end

  defp decrypt_message(_message, _group_keys) do
    nil
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
