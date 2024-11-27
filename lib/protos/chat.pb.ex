defmodule TextMessengerClient.Protobuf.User do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :id, 1, type: :string
  field :name, 2, type: :string
end

defmodule TextMessengerClient.Protobuf.Users do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :users, 1, repeated: true, type: TextMessengerClient.Protobuf.User
end

defmodule TextMessengerClient.Protobuf.Chat do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :id, 1, type: :string
  field :users, 2, repeated: true, type: TextMessengerClient.Protobuf.User
  field :name, 3, type: :string
end

defmodule TextMessengerClient.Protobuf.Chats do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :chats, 1, repeated: true, type: TextMessengerClient.Protobuf.Chat
end

defmodule TextMessengerClient.Protobuf.ChatMessage do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :id, 1, type: :string
  field :user_id, 2, type: :string, json_name: "userId"
  field :chat_id, 3, type: :string, json_name: "chatId"
  field :content, 4, type: :string
  field :timestamp, 5, type: :string
  field :iv, 6, type: :bytes
end

defmodule TextMessengerClient.Protobuf.ChatMessages do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :messages, 1, repeated: true, type: TextMessengerClient.Protobuf.ChatMessage
end

defmodule TextMessengerClient.Protobuf.GroupKey do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :chat_id, 1, type: :string, json_name: "chatId"
  field :recipient_id, 2, type: :string, json_name: "recipientId"
  field :creator_id, 3, type: :string, json_name: "creatorId"
  field :key_number, 4, proto3_optional: true, type: :int32, json_name: "keyNumber"
  field :encrypted_key, 5, type: :bytes, json_name: "encryptedKey"
  field :signature, 6, type: :bytes
end

defmodule TextMessengerClient.Protobuf.GroupKeys do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :group_keys, 1,
    repeated: true,
    type: TextMessengerClient.Protobuf.GroupKey,
    json_name: "groupKeys"
end

defmodule TextMessengerClient.Protobuf.EncryptionKey do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :public_key, 2, type: :bytes, json_name: "publicKey"
end

defmodule TextMessengerClient.Protobuf.EncryptionKeys do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :encryption_keys, 1,
    repeated: true,
    type: TextMessengerClient.Protobuf.EncryptionKey,
    json_name: "encryptionKeys"
end

defmodule TextMessengerClient.Protobuf.SignatureKey do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :public_key, 2, type: :bytes, json_name: "publicKey"
end

defmodule TextMessengerClient.Protobuf.SignatureKeys do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :signature_keys, 1,
    repeated: true,
    type: TextMessengerClient.Protobuf.SignatureKey,
    json_name: "signatureKeys"
end

defmodule TextMessengerClient.Protobuf.UserKeys do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :encryption_key, 2, proto3_optional: true, type: :bytes, json_name: "encryptionKey"
  field :signature_key, 3, proto3_optional: true, type: :bytes, json_name: "signatureKey"
end

defmodule TextMessengerClient.Protobuf.UserKeysList do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :user_keys, 1,
    repeated: true,
    type: TextMessengerClient.Protobuf.UserKeys,
    json_name: "userKeys"
end