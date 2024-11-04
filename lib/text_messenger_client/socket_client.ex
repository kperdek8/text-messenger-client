defmodule TextMessengerClient.SocketClient do
  require Logger

  defmodule WebSocket do
    defstruct [:socket, :channel, :user_id, :chat_id, :liveview_pid]
  end

  def start(user_id, chat_id, liveview_pid) do
    socket_url = Application.get_env(:text_messenger_client, :socket_url)

    {:ok, socket} = PhoenixClient.Socket.start_link(
      url: socket_url,
      params: %{user_id: user_id}
    )

    wait_for_connection(socket)

    case join_chat_room(socket, chat_id) do
      {:ok, channel} ->
        {:ok, %WebSocket{socket: socket, channel: channel, user_id: user_id, chat_id: chat_id, liveview_pid: liveview_pid}}
      {:error, reason} ->
        Logger.error("Failed to join chat room: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def send_message(%WebSocket{channel: channel, user_id: user_id}, content) do
    payload = %{user_id: user_id, content: content}

    case PhoenixClient.Channel.push_async(channel, "new_message", payload) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Failed to push new_message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def add_user(%WebSocket{channel: channel, user_id: user_id}, target_user_id) do
    payload = %{user_id: user_id, target_user_id: target_user_id}

    case PhoenixClient.Channel.push_async(channel, "add_user", payload) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Failed to push add_user: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def change_chat(%WebSocket{socket: socket} = websocket, new_chat_id) do
    PhoenixClient.Channel.leave(websocket.channel)

    case join_chat_room(socket, new_chat_id) do
      {:ok, new_channel} ->
        {:ok, %WebSocket{websocket | channel: new_channel, chat_id: new_chat_id}}
      {:error, reason} ->
        Logger.error("Failed to join new chat room: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_message(%PhoenixClient.Message{event: event, payload: payload}, %WebSocket{liveview_pid: liveview_pid}) do
    send(liveview_pid, {:socket_event, event, payload})
  end

  defp join_chat_room(socket, chat_id) do
    topic = "room:#{chat_id}"

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

  def stop(%WebSocket{channel: channel, socket: socket}) do
    PhoenixClient.Channel.leave(channel)
    PhoenixClient.Socket.stop(socket)
  end
end
