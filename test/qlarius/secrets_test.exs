defmodule Qlarius.SecretsTest do
  use ExUnit.Case, async: false

  alias Qlarius.Secrets

  setup do
    on_exit(fn ->
      for key <- ~w(
        QLARIUS_USE_AWS_SSM GIGALIXIR_APP_NAME DYNO AWS_REGION
        TWILIO_ACCOUNT_SID CLOAK_KEY
      ) do
        System.delete_env(key)
      end
    end)

    :ok
  end

  describe "aws_ssm_enabled?/0" do
    test "returns false on Gigalixir" do
      System.put_env("GIGALIXIR_APP_NAME", "qlarius")
      System.put_env("AWS_REGION", "us-east-1")

      refute Secrets.aws_ssm_enabled?()
    end

    test "returns false when Twilio env vars are set (e.g. Gigalixir migrate one-off)" do
      System.put_env("AWS_REGION", "us-east-1")
      System.put_env("TWILIO_ACCOUNT_SID", "AC123")

      refute Secrets.aws_ssm_enabled?()
    end

    test "returns false when Cloak key env var is set" do
      System.put_env("AWS_REGION", "us-east-1")
      System.put_env("CLOAK_KEY", "dGVzdA==")

      refute Secrets.aws_ssm_enabled?()
    end

    test "returns true on AWS when no PaaS markers or env secrets" do
      System.put_env("AWS_REGION", "us-east-1")

      assert Secrets.aws_ssm_enabled?()
    end

    test "returns false locally without AWS region" do
      refute Secrets.aws_ssm_enabled?()
    end

    test "respects QLARIUS_USE_AWS_SSM override" do
      System.put_env("GIGALIXIR_APP_NAME", "qlarius")
      System.put_env("QLARIUS_USE_AWS_SSM", "true")

      assert Secrets.aws_ssm_enabled?()
    end
  end
end
