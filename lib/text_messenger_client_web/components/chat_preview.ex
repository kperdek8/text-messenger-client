defmodule TextMessengerClientWeb.ChatPreviewComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class={"flex flex-col items-start w-full my-2 transition rounded-lg cursor-pointer active:bg-gray-300/30 " <>
                if @id == @selected_chat, do: "bg-gray-200/20", else: "hover:bg-gray-200/20"} phx-click="select_chat" phx-value-id={@id}>
      <div class="text-white mx-2 text-lg">
        <p><%= @name %></p>
      </div>
      <div class="text-gray-400 w-full pb-2 px-2 rounded-lg max-w-3/4 text-base">
        <p><%= @message %></p>
      </div>
    </div>
    """
  end
end
