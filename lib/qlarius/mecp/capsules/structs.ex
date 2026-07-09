defmodule Qlarius.MeCP.Capsules.Value do
  @moduledoc "A single dated tag value within a capsule trait."

  @type t :: %__MODULE__{
          text: String.t(),
          added_date: NaiveDateTime.t() | Date.t() | nil,
          tag_id: integer() | nil
        }

  @enforce_keys [:text]
  defstruct [:text, :added_date, :tag_id]
end

defmodule Qlarius.MeCP.Capsules.Trait do
  @moduledoc "An effective trait within a capsule category, with its dated values."

  alias Qlarius.MeCP.Capsules.Value

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          display_order: integer() | nil,
          values: [Value.t()]
        }

  defstruct [:id, :name, :display_order, values: []]
end

defmodule Qlarius.MeCP.Capsules.Category do
  @moduledoc "A trait category within a capsule, with its ordered traits."

  alias Qlarius.MeCP.Capsules.Trait

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          display_order: integer() | nil,
          traits: [Trait.t()]
        }

  defstruct [:id, :name, :display_order, traits: []]
end

defmodule Qlarius.MeCP.Capsules.Capsule do
  @moduledoc "A built capsule: an ordered set of categories for one MeFile."

  alias Qlarius.MeCP.Capsules.Category

  @type t :: %__MODULE__{
          me_file_id: integer() | nil,
          categories: [Category.t()]
        }

  defstruct [:me_file_id, categories: []]
end
