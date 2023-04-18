defmodule Kino.Input do
  @moduledoc """
  Various input elements for entering data.

  ## Examples

  First, create an input and make sure it is rendered,
  either by placing it at the end of a code cell or by
  explicitly rendering it with `Kino.render/1`.

      input = Kino.Input.text("Name")

  Then read the value at any later point:

      name = Kino.Input.read(input)

  All inputs are shared by default: once you change the input,
  your changes will be immediately replicated to all users
  reading the notebook. Use `Kino.Control.form/2` if you want
  each user to have their own input.

  ## Async API

  You can subscribe to input changes or use the `Stream`
  API for event feed. See the `Kino.Control` module for
  more details.
  """

  defstruct [:attrs]

  @opaque t :: %__MODULE__{attrs: Kino.Output.input_attrs()}

  defp new(attrs) do
    token = Kino.Bridge.generate_token()
    persistent_id = {token, attrs} |> :erlang.phash2() |> Integer.to_string()

    ref = Kino.Output.random_ref()
    subscription_manager = Kino.SubscriptionManager.cross_node_name()

    attrs =
      Map.merge(attrs, %{
        ref: ref,
        id: persistent_id,
        destination: subscription_manager
      })

    Kino.Bridge.reference_object(ref, self())
    Kino.Bridge.monitor_object(ref, subscription_manager, {:clear_topic, ref})

    %__MODULE__{attrs: attrs}
  end

  @doc false
  def duplicate(input) do
    input.attrs
    |> Map.drop([:ref, :id, :destination])
    |> new()
  end

  @doc """
  Creates a new text input.

  ## Options

    * `:default` - the initial input value. Defaults to `""`
  """
  @spec text(String.t(), keyword()) :: t()
  def text(label, opts \\ []) when is_binary(label) and is_list(opts) do
    default = opts |> Keyword.get(:default, "") |> to_string()
    new(%{type: :text, label: label, default: default})
  end

  @doc """
  Creates a new multiline text input.

  ## Options

    * `:default` - the initial input value. Defaults to `""`

    * `:monospace` - whether to use a monospace font inside the textarea.
      Defaults to `false`
  """
  @spec textarea(String.t(), keyword()) :: t()
  def textarea(label, opts \\ []) when is_binary(label) and is_list(opts) do
    default = opts |> Keyword.get(:default, "") |> to_string()
    monospace = Keyword.get(opts, :monospace, false)

    new(%{
      type: :textarea,
      label: label,
      default: default,
      monospace: monospace
    })
  end

  @doc """
  Creates a new password input.

  This is similar to text input, except the content is not
  visible by default.

  ## Options

    * `:default` - the initial input value. Defaults to `""`
  """
  @spec password(String.t(), keyword()) :: t()
  def password(label, opts \\ []) when is_binary(label) and is_list(opts) do
    default = opts |> Keyword.get(:default, "") |> to_string()
    new(%{type: :password, label: label, default: default})
  end

  @doc """
  Creates a new number input.

  The input value is can be either a number or `nil`.

  ## Options

    * `:default` - the initial input value. Defaults to `nil`
  """
  @spec number(String.t(), keyword()) :: t()
  def number(label, opts \\ []) when is_binary(label) and is_list(opts) do
    default = Keyword.get(opts, :default, nil)

    assert_default_value!(default, "be either number or nil", fn value ->
      is_nil(value) or is_number(value)
    end)

    new(%{type: :number, label: label, default: default})
  end

  defp assert_default_value!(value, message, check) do
    unless check.(value) do
      raise ArgumentError, "expected :default to #{message}, got: #{inspect(value)}"
    end
  end

  @doc """
  Creates a new URL input.

  The input value can be either a valid URL string or `nil`.

  ## Options

    * `:default` - the initial input value. Defaults to `nil`
  """
  @spec url(String.t(), keyword()) :: t()
  def url(label, opts \\ []) when is_binary(label) and is_list(opts) do
    default = Keyword.get(opts, :default, nil)

    assert_default_value!(default, "be either string or nil", fn value ->
      is_nil(value) or is_binary(value)
    end)

    new(%{type: :url, label: label, default: default})
  end

  @doc """
  Creates a new select input.

  The input expects a list of options in the form `[{value, label}]`,
  where `value` is an arbitrary term and `label` is a descriptive
  string.

  ## Options

    * `:default` - the initial input value. Defaults to the first
      value from the given list of options

  ## Examples

      Kino.Input.select("Language", [en: "English", fr: "Français"])

      Kino.Input.select("Language", [{1, "One"}, {2, "Two"}, {3, "Three"}])
  """
  @spec select(String.t(), list({value :: term(), label :: String.t()}), keyword()) :: t()
  def select(label, options, opts \\ [])
      when is_binary(label) and is_list(options) and is_list(opts) do
    if options == [] do
      raise ArgumentError, "expected at least one option, got: []"
    end

    options = Enum.map(options, fn {key, val} -> {key, to_string(val)} end)
    values = Enum.map(options, &elem(&1, 0))
    default = Keyword.get_lazy(opts, :default, fn -> hd(values) end)

    if default not in values do
      raise ArgumentError,
            "expected :default to be either of #{Enum.map_join(values, ", ", &inspect/1)}, got: #{inspect(default)}"
    end

    new(%{type: :select, label: label, options: options, default: default})
  end

  @doc """
  Creates a new checkbox.

  The input value can be either `true` or `false`.

  ## Options

    * `:default` - the initial input value. Defaults to `false`
  """
  @spec checkbox(String.t(), keyword()) :: t()
  def checkbox(label, opts \\ []) when is_binary(label) and is_list(opts) do
    default = Keyword.get(opts, :default, false)
    assert_default_value!(default, "be a boolean", &is_boolean/1)
    new(%{type: :checkbox, label: label, default: default})
  end

  @doc """
  Creates a new slider input.

  The input value can be either float in the configured range.

  ## Options

    * `:default` - the initial input value. Defaults to the
      minimum value

    * `:min` - the minimum value

    * `:max` - the maximum value

    * `:step` - the slider increment
  """
  @spec range(String.t(), keyword()) :: t()
  def range(label, opts \\ []) when is_binary(label) and is_list(opts) do
    min = Keyword.get(opts, :min, 0)
    max = Keyword.get(opts, :max, 100)
    step = Keyword.get(opts, :step, 1)
    default = Keyword.get(opts, :default, min)

    if min >= max do
      raise ArgumentError,
            "expected :min to be less than :max, got: #{inspect(min)} and #{inspect(max)}"
    end

    if step <= 0 do
      raise ArgumentError, "expected :step to be positive, got: #{inspect(step)}"
    end

    assert_default_value!(default, "be a number", &is_number/1)

    if default < min or default > max do
      raise ArgumentError,
            "expected :default to be between :min and :max, got: #{inspect(default)}"
    end

    new(%{
      type: :range,
      label: label,
      default: default,
      min: min,
      max: max,
      step: step
    })
  end

  @doc """
  Creates a new color input.

  The input value can be a hex color string.

  ## Options

    * `:default` - the initial input value. Defaults to `#6583FF`
  """
  @spec color(String.t(), keyword()) :: t()
  def color(label, opts \\ []) when is_binary(label) and is_list(opts) do
    default = Keyword.get(opts, :default, "#6583FF")
    assert_default_value!(default, "be a string", &is_binary/1)
    new(%{type: :color, label: label, default: default})
  end

  @doc """
  Creates a new image input.

  The input value is a map, with the image binary and metadata:

      %{
        data: binary(),
        height: pos_integer(),
        width: pos_integer(),
        format: :rgb | :png | :jpeg
      }

  Note that the value can also be `nil`, if no image is selected.

  > #### Warning {: .warning}
  >
  > The image input is shared by default: once you upload a image,
  > the image will be replicated to all users reading the notebook.
  > Use `Kino.Control.form/2` if you want each user to have a distinct
  > image upload with an explicit submission button.

  ## Options

    * `:format` - the format to read the image as, either of:

      * `:rgb` (default) - the binary includes raw pixel values, each
        encoded as a single byte in the HWC order. Such binary can be
        directly converted to an `Nx` tensor, with no additional decoding

      * `:png`

      * `:jpeg` (or `:jpg`)

    * `:size` - the size to fit the image into, given as `{height, width}`

    * `:fit` - the strategy of fitting the image into `:size`, either of:

      * `:contain` (default) - resizes the image, such that it fits in
        a box of `:size`, but preserving the aspect ratio. The resulting
        image can be smaller or equal to `:size`

      * `:match` - resizes the image to `:size`, with no respect for
        aspect ratio

      * `:pad` - same as `:contain`, but pads the image to match `:size`
        exactly

      * `:crop` - resizes the image, such that one edge fits in `:size`
        and the other overflows, then center-crops the image to match
        `:size` exactly

  """
  @spec image(String.t(), keyword()) :: t()
  def image(label, opts \\ []) do
    format =
      case Keyword.get(opts, :format, :rgb) do
        :rgb ->
          :rgb

        :png ->
          :png

        :jpeg ->
          :jpeg

        :jpg ->
          :jpeg

        other ->
          raise ArgumentError,
                "expected :format to be either of :rgb, :png or :jpeg/:jpg, got: #{inspect(other)}"
      end

    size = Keyword.get(opts, :size, nil)
    fit = Keyword.get(opts, :fit, :contain)

    unless fit in [:match, :contain, :pad, :crop] do
      raise ArgumentError,
            "expected :fit to be either of :contain, :match, :pad or :crop, got: #{inspect(fit)}"
    end

    new(%{type: :image, label: label, default: nil, size: size, format: format, fit: fit})
  end

  @doc """
  Creates a new audio input.

  The input value is a map, with the audio binary and metadata:

      %{
        data: binary(),
        num_channels: pos_integer(),
        sampling_rate: pos_integer()
      }

  Note that the value can also be `nil`, if no audio is selected.

  > #### Warning {: .warning}
  >
  > The audio input is shared by default: once you upload an audio,
  > the audio will be replicated to all users reading the notebook.
  > Use `Kino.Control.form/2` if you want each user to have a distinct
  > audio upload with an explicit submission button.

  ## Options

    * `:format` - the format to read the audio as, either of:

      * `:pcm_f32` (default) - the PCM (32-bit float) format. Note that
        the binary uses native system endianness. Such binary can be
        directly converted to an `Nx` tensor, with no additional decoding

      * `:wav`

    * `:sampling_rate` - the sampling rate (samples per second) of
      the audio data. Defaults to `48_000`

  """
  @spec audio(String.t(), keyword()) :: t()
  def audio(label, opts \\ []) do
    format = Keyword.get(opts, :format, :pcm_f32)
    sampling_rate = Keyword.get(opts, :sampling_rate, 48_000)

    unless format in [:pcm_f32, :wav] do
      raise ArgumentError,
            "expected :format to be either of :pcm_f32 or :wav, got: #{inspect(format)}"
    end

    new(%{type: :audio, label: label, default: nil, format: format, sampling_rate: sampling_rate})
  end

  @doc """
  Creates a new file input.

  The input value is a map, with the file path and metadata:

      %{
        file_ref: String.t(),
        client_name: String.t()
      }

  Note that the value can also be `nil`, if no file is selected.

  The file path can then be accessed using `file_path/1`.

  > #### Warning {: .warning}
  >
  > The file input is shared by default: once you upload a file,
  > the file will be replicated to all users reading the notebook.
  > Use `Kino.Control.form/2` if you want each user to have a distinct
  > file upload with an explicit submission button.

  ## Considerations

  Note that a file may be deleted in certain cases, specifically:

    * when the file is reuploaded
    * when used with a form and the uploading user leaves
    * when the input is removed

  The deletion is not immediate and you are unlikely to run into this
  in practice, however theoretically `file_path/1` may point to a
  non-existing file.

  ## Options

    * `:accept` - the list of accepted file types (either extensions
      or MIME types) or `:any`. Defaults to `:any`

  ## Examples

  To read the content of currently uploaded file we would do:

      # [Cell 1]

      input = Kino.Input.file("File")

      # [Cell 2]

      value = Kino.Input.read(input)
      path = Kino.Input.file_path(value.file_ref)
      File.read!(path)

  And here's how we could process an asynchronous form submission:

      # [Cell 1]

      form = Kino.Control.form([file: Kino.Input.file("File")], submit: "Send")

      # [Cell 2]

      form
      |> Kino.Control.stream()
      |> Kino.listen(fn event ->
        path = Kino.Input.file_path(event.data.file.file_ref)
        content = File.read!(path)
        IO.inspect(content)
      end)

  """

  @spec file(String.t(), keyword()) :: t()
  def file(label, opts \\ []) when is_binary(label) and is_list(opts) do
    accept = Keyword.get(opts, :accept, :any)

    case accept do
      :any ->
        :ok

      [_ | _] ->
        :ok

      other ->
        raise ArgumentError, "expected :accept to be a non-empty list, got: #{inspect(other)}"
    end

    new(%{type: :file, label: label, default: nil, accept: accept})
  end

  @doc """
  Synchronously reads the current input value.

  Note that to retrieve the value, the input must be rendered first,
  otherwise an error is raised.

  ## Examples

      input = Kino.Input.text("Name")

      Kino.Input.read(input)
  """
  @spec read(t()) :: term()
  def read(%Kino.Input{} = input) do
    case Kino.Bridge.get_input_value(input.attrs.id) do
      {:ok, value} ->
        value

      {:error, reason} ->
        raise "failed to read input value, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Returns file path for the given file identifier.
  """
  @spec file_path(file_ref) :: String.t() when file_ref: {:file, id :: String.t()}
  def file_path({:file, file_id} = file_ref) do
    case Kino.Bridge.get_file_path(file_ref) do
      {:ok, path} ->
        path

      {:error, _reason} ->
        # Return a non-existing path for consistency
        Path.join([System.tmp_dir!(), "nonexistent", file_id])
    end
  end

  def radio(label, options, opts \\ [])
      when is_binary(label) and is_list(options) and is_list(opts) do
    if options == [] do
      raise ArgumentError, "expected at least one option, got: []"
    end

    options = Enum.map(options, fn {key, val} -> {key, to_string(val)} end)
    values = Enum.map(options, &elem(&1, 0))
    default = Keyword.get_lazy(opts, :default, fn -> hd(values) end)

    if default not in values do
      raise ArgumentError,
            "expected :default to be either of #{Enum.map_join(values, ", ", &inspect/1)}, got: #{inspect(default)}"
    end

    new(%{type: :radio, label: label, options: options, default: default})
  end
end

defimpl Enumerable, for: Kino.Input do
  def reduce(input, acc, fun), do: Enumerable.reduce(Kino.Control.stream([input]), acc, fun)
  def member?(_input, _value), do: {:error, __MODULE__}
  def count(_input), do: {:error, __MODULE__}
  def slice(_input), do: {:error, __MODULE__}
end
