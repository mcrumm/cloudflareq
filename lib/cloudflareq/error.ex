defmodule Cloudflareq.Error do
  defstruct [:code, :message]

  @type t :: %__MODULE__{
          code: integer() | nil,
          message: String.t() | nil
        }

  def new(%{"code" => code, "message" => message}) do
    %__MODULE__{code: code, message: message}
  end

  def new(%{} = map) do
    %__MODULE__{code: map["code"], message: map["message"]}
  end

  defimpl String.Chars do
    def to_string(%Cloudflareq.Error{code: code, message: message}) do
      "[#{code}] #{message}"
    end
  end
end
