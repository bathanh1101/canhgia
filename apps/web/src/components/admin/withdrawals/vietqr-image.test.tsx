import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { VietQrImage } from "./vietqr-image";

describe("VietQrImage", () => {
  it("renders a generated QR image", async () => {
    render(<VietQrImage bin="970436" account="1020304050" amount={100000} addInfo="CANHGIA 1a2b3c4d" />);
    const img = await screen.findByAltText("Mã VietQR chuyển khoản");
    expect(img.getAttribute("src")).toMatch(/^data:image\/png;base64,/);
  });

  it("shows an error instead of a QR for invalid bank data", async () => {
    render(<VietQrImage bin="12" account="1020304050" amount={100000} addInfo="X" />);
    expect(await screen.findByRole("alert")).toHaveTextContent("Không tạo được mã QR");
  });
});
