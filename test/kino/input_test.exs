defmodule Kino.InputTest do
  use ExUnit.Case, async: true

  describe "text/2" do
    test "converts the default value to string" do
      assert %{attrs: %{default: "10"}} = Kino.Input.text("Message", default: 10)
    end
  end

  describe "number/2" do
    test "raises an error on invalid default value" do
      assert_raise ArgumentError,
                   ~s/expected :default to be either number or nil, got: "10"/,
                   fn ->
                     Kino.Input.number("Message", default: "10")
                   end
    end
  end

  describe "select/3" do
    test "raises an error for empty option list" do
      assert_raise ArgumentError, "expected at least one option, got: []", fn ->
        Kino.Input.select("Language", [])
      end
    end

    test "raises an error when the default value does not match any option" do
      assert_raise ArgumentError, "expected :default to be either of :en, :fr, got: :pl", fn ->
        Kino.Input.select("Language", [en: "English", fr: "Français"], default: :pl)
      end
    end
  end

  describe "range/2" do
    test "raises an error when min is less than max" do
      assert_raise ArgumentError, "expected :min to be less than :max, got: 10 and 0", fn ->
        Kino.Input.range("Length", min: 10, max: 0)
      end
    end

    test "raises an error when step is negative" do
      assert_raise ArgumentError, "expected :step to be positive, got: -1", fn ->
        Kino.Input.range("Length", step: -1)
      end
    end

    test "raises an error when the default is out of range" do
      assert_raise ArgumentError, "expected :default to be between :min and :max, got: 20", fn ->
        Kino.Input.range("Length", min: 0, max: 10, default: 20)
      end
    end
  end

  describe "file/2" do
    test "raises an error when :accept is an empty list" do
      assert_raise ArgumentError, "expected :accept to be a non-empty list, got: []", fn ->
        Kino.Input.file("File", accept: [])
      end
    end
  end
end
