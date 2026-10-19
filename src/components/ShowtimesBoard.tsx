"use client";

import { useMemo, useState } from "react";
import { Filters, filterShowtimes, type FilterState } from "@/components/Filters";
import { MovieCard } from "@/components/MovieCard";
import { groupByMovie, showtimeDay } from "@/lib/showtimes-utils";
import type { ShowtimesSnapshot } from "@/types/showtimes";

export function ShowtimesBoard({ snapshot }: { snapshot: ShowtimesSnapshot }) {
  const [filters, setFilters] = useState<FilterState>({
    day: "",
    cinemaKey: "",
    room: "",
  });

  const days = useMemo(() => {
    const set = new Set(snapshot.showtimes.map((s) => showtimeDay(s.startsAt)));
    return Array.from(set).sort();
  }, [snapshot.showtimes]);

  const rooms = useMemo(() => {
    const set = new Set(snapshot.showtimes.map((s) => s.roomLabel));
    return Array.from(set).sort((a, b) => a.localeCompare(b, "fr"));
  }, [snapshot.showtimes]);

  const filtered = useMemo(
    () => filterShowtimes(snapshot.showtimes, filters),
    [snapshot.showtimes, filters],
  );

  const groups = useMemo(() => groupByMovie(filtered), [filtered]);

  const updatedLabel = useMemo(() => {
    try {
      return new Intl.DateTimeFormat("fr-FR", {
        dateStyle: "medium",
        timeStyle: "short",
        timeZone: "Europe/Paris",
      }).format(new Date(snapshot.fetchedAt));
    } catch {
      return snapshot.fetchedAt;
    }
  }, [snapshot.fetchedAt]);

  if (snapshot.error) {
    return (
      <div className="rounded-xl border border-amber-500/30 bg-amber-500/10 px-5 py-6 text-amber-100">
        <p className="font-semibold">Données indisponibles</p>
        <p className="mt-2 text-sm text-amber-100/80">{snapshot.error}</p>
      </div>
    );
  }

  if (snapshot.showtimes.length === 0) {
    return (
      <div className="rounded-xl border border-white/10 bg-[var(--surface)] px-5 py-10 text-center">
        <p className="font-[family-name:var(--font-display)] text-xl">
          Aucune séance VOST cette semaine
        </p>
        <p className="mt-2 text-sm text-[var(--muted)]">
          Réessaie plus tard — les programmes changent souvent.
        </p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-8">
      <div className="flex flex-col gap-4">
        <Filters
          cinemas={snapshot.cinemas}
          days={days}
          rooms={rooms}
          value={filters}
          onChange={setFilters}
          resultCount={filtered.length}
        />
        <p className="text-xs text-[var(--muted)]">
          Mis à jour le {updatedLabel} · horaires non contractuels — vérifie
          toujours sur le site du cinéma.
        </p>
      </div>

      {groups.length === 0 ? (
        <div className="rounded-xl border border-white/10 bg-[var(--surface)] px-5 py-10 text-center text-[var(--muted)]">
          Aucune séance pour ces filtres.
        </div>
      ) : (
        <div>
          {groups.map((group) => (
            <MovieCard
              key={
                group.movie.tmdbId
                  ? `tmdb-${group.movie.tmdbId}`
                  : group.movie.id
              }
              group={group}
            />
          ))}
        </div>
      )}
    </div>
  );
}
