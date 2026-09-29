import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";

const adjust = vi.hoisted(() => vi.fn());
vi.mock("@/app/admin/users/actions", () => ({ adjustWallet: adjust }));
vi.mock("@/components/admin-kit/notify-result", () => ({ notifyResult: vi.fn() }));

import { AdjustWalletDialog } from "./adjust-wallet-dialog";

const uid = "1a2b3c4d-1111-4222-8333-444455556666";

async function openAndFill(user: ReturnType<typeof userEvent.setup>) {
  await user.click(screen.getByRole("button", { name: "Mở" }));
  await user.type(screen.getByLabelText("Số tiền (đ)"), "5000");
  await user.type(screen.getByLabelText(/Lý do/), "Đền bù đơn lỗi");
  await user.click(screen.getByRole("button", { name: "Tiếp tục" }));
}

describe("AdjustWalletDialog idempotency key", () => {
  beforeEach(() => adjust.mockReset());

  it("keeps the same request id across a failed submit and its retry", async () => {
    adjust.mockResolvedValue({ ok: false, error: "x" });
    const user = userEvent.setup();
    render(<AdjustWalletDialog userId={uid} trigger={<button>Mở</button>} />);
    await openAndFill(user);
    await user.click(screen.getByRole("button", { name: "Xác nhận điều chỉnh" }));
    await waitFor(() => expect(adjust).toHaveBeenCalledTimes(1));
    await user.click(await screen.findByRole("button", { name: "Xác nhận điều chỉnh" }));
    await waitFor(() => expect(adjust).toHaveBeenCalledTimes(2));
    const [first, second] = adjust.mock.calls.map((c) => c[3]);
    expect(first).toMatch(/^[0-9a-f-]{36}$/);
    expect(second).toBe(first);
  });

  it("uses a fresh id after a successful adjustment", async () => {
    adjust.mockResolvedValue({ ok: true });
    const user = userEvent.setup();
    render(<AdjustWalletDialog userId={uid} trigger={<button>Mở</button>} />);
    await openAndFill(user);
    await user.click(screen.getByRole("button", { name: "Xác nhận điều chỉnh" }));
    await waitFor(() => expect(adjust).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
    await openAndFill(user);
    await user.click(screen.getByRole("button", { name: "Xác nhận điều chỉnh" }));
    await waitFor(() => expect(adjust).toHaveBeenCalledTimes(2));
    expect(adjust.mock.calls[1][3]).not.toBe(adjust.mock.calls[0][3]);
  });
});
