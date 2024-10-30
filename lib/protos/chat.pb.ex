defmodule User do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :int32)
  field(:name, 2, type: :string)
end

defmodule Users do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:users, 1, repeated: true, type: User)
end

defmodule Chat do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :int32)
  field(:users, 2, repeated: true, type: User)
  field(:name, 3, type: :string)
end

defmodule Chats do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:chats, 1, repeated: true, type: Chat)
end

defmodule ChatMessage do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :int32)
  field(:user_id, 2, type: :int32, json_name: "userId")
  field(:chat_id, 3, type: :int32, json_name: "chatId")
  field(:content, 4, type: :string)
  field(:timestamp, 5, type: :string)
end

defmodule ChatMessages do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:messages, 1, repeated: true, type: ChatMessage)
end
