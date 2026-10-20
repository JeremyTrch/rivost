"use client";

import { formatDayShort } from "@/lib/dates";
import type { Cinema, Showtime } from "@/types/showtimes";

export interface FilterState {
  day: string;
  cinemaKey: string;
  room: string;
}

interface FiltersProps {
  cinemas: Cinema[];
  days: string[];
  rooms: string[];
  today: string;
  value: FilterState;
  onChange: (next: FilterState) => void;
  resultCount: number;
  stuck?: boolean;
}

function shortCinemaLabel(c: Cinema): string {
  if (c.key === "cineum-cannes") return "Cinéum";
  if (c.key === "pathe-lingostiere") return "Pathé";
  if (c.key === "cgr-cagnes") return "CGR";
  if (c.key === "cineplanet-antibes") return "Cinéplanet";
  return c.label;
}

export function Filters({
  cinemas,
  days,
  rooms,
  today,
  value,
  onChange,
  resultCount,
  stuck = false,
}: FiltersProps) {
  const hasActive = Boolean(value.day || value.cinemaKey || value.room);

  return (
    <div className="filters-bar" data-stuck={stuck ? "true" : "false"}>
      <div className="flex flex-col gap-3">
        <div className="flex items-center justify-between gap-3">
          <p className="text-[0.7rem] font-semibold uppercase tracking-[0.2em] text-[var(--muted)]">
            Filtrer
          </p>
          <div className="flex items-center gap-3 text-sm text-[var(--muted)]">
            <span className="tabular-nums text-[var(--fog)]">
              {resultCount} séance{resultCount === 1 ? "" : "s"}
            </span>
            {hasActive ? (
              <button
                type="button"
                className="text-[var(--accent)] transition hover:text-[var(--accent-hot)]"
                onClick={() =>
                  onChange({ day: "", cinemaKey: "", room: "" })
                }
              >
                Réinitialiser
              </button>
            ) : null}
          </div>
        </div>

        <div
          className="-mx-1 flex gap-2 overflow-x-auto px-1 pb-0.5 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
          role="listbox"
          aria-label="Jour"
        >
          <button
            type="button"
            className="chip"
            data-active={value.day === "" ? "true" : "false"}
            onClick={() => onChange({ ...value, day: "" })}
          >
            Semaine
          </button>
          {days.map((day) => (
            <button
              key={day}
              type="button"
              className="chip"
              data-active={value.day === day ? "true" : "false"}
              onClick={() => onChange({ ...value, day })}
            >
              {formatDayShort(day, today)}
            </button>
          ))}
        </div>

        <div
          className="-mx-1 flex gap-2 overflow-x-auto px-1 pb-0.5 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
          role="listbox"
          aria-label="Cinéma"
        >
          <button
            type="button"
            className="chip"
            data-active={value.cinemaKey === "" ? "true" : "false"}
            onClick={() => onChange({ ...value, cinemaKey: "" })}
          >
            Tous les cinés
          </button>
          {cinemas.map((c) => (
            <button
              key={c.key}
              type="button"
              className="chip"
              data-active={value.cinemaKey === c.key ? "true" : "false"}
              onClick={() => onChange({ ...value, cinemaKey: c.key })}
              title={c.label}
            >
              {shortCinemaLabel(c)}
            </button>
          ))}
        </div>

        {rooms.length > 1 ? (
          <label className="flex max-w-xs flex-col gap-1.5 text-[0.7rem] font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
            Salle
            <select
              className="rounded-lg border border-[var(--line)] bg-[var(--surface)] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[var(--foreground)] outline-none focus:border-[var(--accent)]/50"
              value={value.room}
              onChange={(e) => onChange({ ...value, room: e.target.value })}
            >
              <option value="">Toutes</option>
              {rooms.map((room) => (
                <option key={room} value={room}>
                  {room}
                </option>
              ))}
            </select>
          </label>
        ) : null}
      </div>
    </div>
  );
}

export function filterShowtimes(
  showtimes: Showtime[],
  filters: FilterState,
): Showtime[] {
  return showtimes.filter((st) => {
    if (filters.day && !st.startsAt.startsWith(filters.day)) return false;
    if (filters.cinemaKey && st.cinema.key !== filters.cinemaKey) return false;
    if (filters.room && st.roomLabel !== filters.room) return false;
    return true;
  });
}
