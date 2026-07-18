defmodule ExweaverWeb.SerializerSpec do
  use ESpec

  import Exweaver.Factory

  alias ExweaverWeb.Serializer

  describe "iso8601/1" do
    context "when the timestamp is nil" do
      it "returns nil rather than raising" do
        expect(Serializer.iso8601(nil)) |> to(be_nil())
      end
    end

    context "when the timestamp is a DateTime" do
      it "renders it as a UTC ISO8601 string" do
        datetime = ~U[2026-07-12 09:30:00Z]

        expect(Serializer.iso8601(datetime)) |> to(eq("2026-07-12T09:30:00Z"))
      end
    end
  end

  describe "page/3" do
    it "wraps the rendered items under a data key" do
      role = build(:role, name: "admin")

      page = Serializer.page([role], nil, &Serializer.role/1)

      expect(page.data) |> to(eq([Serializer.role(role)]))
    end

    it "carries the next_cursor through" do
      page = Serializer.page([], "019f-cursor", &Serializer.role/1)

      expect(page.next_cursor) |> to(eq("019f-cursor"))
    end
  end

  describe "customer/1" do
    context "when the customer has no password" do
      it "reports a pending status" do
        customer = build(:customer, hashed_password: nil)

        expect(Serializer.customer(customer).status) |> to(eq("pending"))
      end
    end

    context "when the customer has a password" do
      it "reports an active status" do
        customer = build(:customer, hashed_password: "hashed")

        expect(Serializer.customer(customer).status) |> to(eq("active"))
      end
    end
  end

  describe "access_key/2" do
    context "when no token is supplied" do
      it "renders a nil token (the value is never re-exposed)" do
        access_key = build(:access_key)

        expect(Serializer.access_key(access_key).token) |> to(be_nil())
      end
    end

    context "when the one-time token is supplied" do
      it "includes the plaintext token" do
        access_key = build(:access_key)

        expect(Serializer.access_key(access_key, "exw_secret").token) |> to(eq("exw_secret"))
      end
    end

    context "when the key never expires" do
      it "renders a nil expired_at" do
        access_key = build(:access_key, expired_at: nil)

        expect(Serializer.access_key(access_key).expired_at) |> to(be_nil())
      end
    end
  end
end
