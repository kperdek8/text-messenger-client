defmodule TextMessengerServer.Protobuf.User do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :id, 1, type: :string
  field :name, 2, type: :string
end

defmodule TextMessengerServer.Protobuf.Users do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :users, 1, repeated: true, type: TextMessengerServer.Protobuf.User
end

defmodule TextMessengerServer.Protobuf.Chat do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :id, 1, type: :string
  field :users, 2, repeated: true, type: TextMessengerServer.Protobuf.User
  field :name, 3, type: :string
end

defmodule TextMessengerServer.Protobuf.Chats do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :chats, 1, repeated: true, type: TextMessengerServer.Protobuf.Chat
end

defmodule TextMessengerServer.Protobuf.ChatMessage do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :id, 1, type: :string
  field :user_id, 2, type: :string, json_name: "userId"
  field :chat_id, 3, type: :string, json_name: "chatId"
  field :content, 4, type: :string
  field :timestamp, 5, type: :string
end

defmodule TextMessengerServer.Protobuf.ChatMessages do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :messages, 1, repeated: true, type: TextMessengerServer.Protobuf.ChatMessage
end

defmodule TextMessengerServer.Protobuf.GroupKey do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :chat_id, 1, type: :string, json_name: "chatId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :key_number, 3, proto3_optional: true, type: :int32, json_name: "keyNumber"
  field :encrypted_key, 4, type: :bytes, json_name: "encryptedKey"
end

defmodule TextMessengerServer.Protobuf.GroupKeys do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :group_keys, 1,
    repeated: true,
    type: TextMessengerServer.Protobuf.GroupKey,
    json_name: "groupKeys"
end

defmodule TextMessengerServer.Protobuf.EncryptionKey do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :encrypted_key, 2, type: :bytes, json_name: "encryptedKey"
end

defmodule TextMessengerServer.Protobuf.EncryptionKeys do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :encryption_keys, 1,
    repeated: true,
    type: TextMessengerServer.Protobuf.EncryptionKey,
    json_name: "encryptionKeys"
end

defmodule TextMessengerServer.Protobuf.SignatureKey do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :encrypted_key, 2, type: :bytes, json_name: "encryptedKey"
end

defmodule TextMessengerServer.Protobuf.SignatureKeys do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :signature_keys, 1,
    repeated: true,
    type: TextMessengerServer.Protobuf.SignatureKey,
    json_name: "signatureKeys"
end