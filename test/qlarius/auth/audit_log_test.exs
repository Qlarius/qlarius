defmodule Qlarius.Auth.AuditLogTest do
  # `ExUnit.CaptureLog` is the system under test here; no DB, no
  # async (CaptureLog is process-scoped but setting level is global).
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Qlarius.Auth.AuditLog

  setup do
    # Logger level may be :warning in test — force :info so our audit
    # lines are captured.
    prev_level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: prev_level) end)
    :ok
  end

  describe "log/2" do
    test "emits a single line with the event name" do
      log =
        capture_log(fn ->
          AuditLog.log(:"send_code.allowed", %{
            phone: "+15551234567",
            ip: "1.2.3.4",
            surface: :on_qlink_page
          })
        end)

      assert log =~ "auth_event send_code.allowed"
    end

    test "masks the phone number to its last 4 digits" do
      log =
        capture_log(fn ->
          AuditLog.log(:"send_code.allowed", %{
            phone: "+15551234567",
            ip: "1.2.3.4",
            surface: :on_qlink_page
          })
        end)

      assert log =~ "phone_masked=+*******4567"
      refute log =~ "5551234567"
    end

    test "handles :mobile_number key as an alias for :phone" do
      log =
        capture_log(fn ->
          AuditLog.log(:"register_new_user.denied", %{
            mobile_number: "5551234567",
            ip: "1.2.3.4",
            surface: :on_widget_standalone,
            failed_step: :user
          })
        end)

      assert log =~ "phone_masked=******4567"
      refute log =~ "mobile_number="
    end

    test "masks nil / short / non-binary phones defensively" do
      log =
        capture_log(fn ->
          AuditLog.log(:"send_code.denied", %{phone: nil, ip: "1.2.3.4"})
          AuditLog.log(:"send_code.denied", %{phone: "abc", ip: "1.2.3.4"})
        end)

      assert log =~ "phone_masked=****"
    end

    test "renders the IP, surface, and reason verbatim" do
      log =
        capture_log(fn ->
          AuditLog.log(:"send_code.denied", %{
            phone: "+15551234567",
            ip: "1.2.3.4",
            surface: :on_qlinkin_bio,
            reason: :phone_limit,
            retry_after_s: 600
          })
        end)

      assert log =~ "ip=1.2.3.4"
      assert log =~ "surface=on_qlinkin_bio"
      assert log =~ "reason=phone_limit"
      assert log =~ "retry_after_s=600"
    end

    test "preferred key order is stable regardless of map insertion order" do
      log =
        capture_log(fn ->
          AuditLog.log(:"verify_code.allowed", %{
            user_id: 42,
            outcome: :signed_in,
            surface: :on_qlink_page,
            ip: "1.2.3.4",
            phone: "+15551234567"
          })
        end)

      # phone_masked first, then ip, then surface, then outcome, then user_id
      assert log =~
               ~r/phone_masked=\S+ ip=1\.2\.3\.4 surface=on_qlink_page .*outcome=signed_in.*user_id=42/
    end

    test "returns :ok and produces capturable output" do
      {return, log} =
        with_log(fn ->
          AuditLog.log(:"send_code.allowed", %{
            phone: "+15551234567",
            ip: "1.2.3.4",
            surface: :on_qlink_page
          })
        end)

      assert return == :ok
      assert log =~ "auth_event send_code.allowed"
    end
  end

  describe "mask_phone/1" do
    test "keeps the last four digits" do
      assert AuditLog.mask_phone("+15551234567") == "+*******4567"
      assert AuditLog.mask_phone("5551234567") == "******4567"
    end

    test "short / nil / junk input" do
      assert AuditLog.mask_phone(nil) == "****"
      assert AuditLog.mask_phone("") == ""
      assert AuditLog.mask_phone("abc") == ""
      assert AuditLog.mask_phone("123") == "***"
      assert AuditLog.mask_phone(42) == "****"
    end
  end
end
