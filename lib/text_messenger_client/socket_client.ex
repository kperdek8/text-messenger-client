defmodule TextMessengerClient.SocketClient do
  require Logger

  alias TextMessengerClient.Helpers.JWT
  alias TextMessengerClient.Protobuf.GroupKeys

  defmodule WebSocket do
    defstruct [:socket, :chat_channel, :notif_channel, :token, :chat_id, :liveview_pid]
  end

  def start(token) do
    socket_url = Application.get_env(:text_messenger_client, :socket_url)

    {:ok, socket} = PhoenixClient.Socket.start_link(
      url: socket_url,
      params: %{token: token}
    )

    wait_for_connection(socket)
    notif_channel =
      case join_notif_channel(socket, token) do
        {:ok, channel} -> channel
        {:error, %{"reason" => reason}} ->
          IO.inspect("Could not join notification channel: #{reason}")
          nil
      end

    {:ok, %WebSocket{socket: socket, chat_channel: nil, notif_channel: notif_channel, token: token, chat_id: nil}}
  end

  def send_message(%WebSocket{chat_channel: channel}, content) do
    payload = %{content: content}

    case PhoenixClient.Channel.push_async(channel, "new_message", payload) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Failed to push new_message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def send_keys(%WebSocket{chat_channel: channel}, %GroupKeys{} = keys) do
    payload = %{"group_keys" => Base.encode64(GroupKeys.encode(keys))}
    case PhoenixClient.Channel.push(channel, "change_group_key", payload) do
      {:ok, _message} ->
        :ok
      {:error, %{"error" => error}} ->
        Logger.error("Error received from server: #{error}")
      {:error, reason} ->
        Logger.error("Failed to push new_message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def add_user(%WebSocket{chat_channel: channel}, target_user_id) do
    payload = %{user_id: target_user_id}

    case PhoenixClient.Channel.push_async(channel, "add_user", payload) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Failed to push add_user: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def kick_user(%WebSocket{chat_channel: channel}, target_user_id) do
    payload = %{user_id: target_user_id}

    case PhoenixClient.Channel.push_async(channel, "kick_user", payload) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Failed to push add_user: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def change_chat(%WebSocket{socket: socket, chat_channel: channel} = websocket, new_chat_id) do
    if channel != nil do
      PhoenixClient.Channel.leave(channel)
    end

    case join_chat(socket, new_chat_id) do
      {:ok, new_channel} ->
        {:ok, %WebSocket{websocket | chat_channel: new_channel, chat_id: new_chat_id}}
      {:error, reason} ->
        Logger.error("Failed to join new chat room: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp join_chat(socket, chat_id) do
    topic = "chat:#{chat_id}"

    case PhoenixClient.Channel.join(socket, topic) do
      {:ok, _, channel} ->
        {:ok, channel}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp join_notif_channel(socket, token) do
    {:ok, payload} = JWT.decode_payload(token)
    user_id = payload["sub"]
    topic = "notifications:#{user_id}"

    case PhoenixClient.Channel.join(socket, topic) do
      {:ok, _, channel} ->
        {:ok, channel}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp wait_for_connection(socket_pid) do
    unless PhoenixClient.Socket.connected?(socket_pid) do
      :timer.sleep(100)
      wait_for_connection(socket_pid)
    end
  end

  def stop(%WebSocket{chat_channel: chat_channel, notif_channel: notif_channel, socket: socket}) do
    if Process.alive?(chat_channel) do
      PhoenixClient.Channel.leave(chat_channel)
    end
    if Process.alive?(notif_channel) do
      PhoenixClient.Channel.leave(notif_channel)
    end
    if Process.alive?(socket) do
      PhoenixClient.Socket.stop(socket)
    end
  end
end
