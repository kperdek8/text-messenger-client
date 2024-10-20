defmodule TextMessengerClientWeb.ChatMessageComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="flex flex-none flex-col items-start">
      <div class="text-sm text-gray-400">
        <p><%= @user %></p>
      </div>
      <!--TODO: textbg-teal-100 for client's messages -->
      <div class="bg-gray-600 text-white p-4 rounded-lg max-w-3/4 mb-3 shadow-md">
        <p><%= @message %></p>
      </div>
    </div>
    """
  end
end
