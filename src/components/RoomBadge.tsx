const PREMIUM = /imax|4dx|dolby|lounge|lodge|atmos|vip|premium|laser|ice|3d|screen\s*x|cosy|aurore/i;

export function RoomBadge({ label }: { label: string }) {
  const premium = PREMIUM.test(label);

  return (
    <span
      className={
        premium
          ? "inline-flex items-center rounded px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-[0.06em] text-[var(--accent-hot)]"
          : "inline-flex items-center rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-[0.06em] text-[var(--muted)]"
      }
    >
      {label}
    </span>
  );
}
