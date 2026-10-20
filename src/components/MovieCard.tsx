import Image from "next/image";
import { RoomBadge } from "@/components/RoomBadge";
import { formatDayLong } from "@/lib/dates";
import { showtimeDay, showtimeTime } from "@/lib/showtimes-utils";
import type { MovieGroup } from "@/types/showtimes";

function durationLabel(min: number | null): string | null {
  if (!min) return null;
  const h = Math.floor(min / 60);
  const m = min % 60;
  return h > 0 ? `${h}h${String(m).padStart(2, "0")}` : `${m} min`;
}

function shortCinema(label: string): string {
  return label
    .replace("Pathé Lingostière Nice", "Pathé Lingostière")
    .replace("CGR Cagnes-sur-Mer", "CGR Cagnes")
    .replace("Cinéplanet Antibes", "Cinéplanet")
    .replace("Cinéum Cannes", "Cinéum");
}

export function MovieCard({
  group,
  index = 0,
}: {
  group: MovieGroup;
  index?: number;
}) {
  const { movie, showtimes } = group;
  const byCinema = new Map<string, typeof showtimes>();

  for (const st of showtimes) {
    const key = st.cinema.key;
    const list = byCinema.get(key) ?? [];
    list.push(st);
    byCinema.set(key, list);
  }

  const duration = durationLabel(movie.durationMin);
  const meta = [
    movie.originalTitle && movie.originalTitle !== movie.title
      ? movie.originalTitle
      : null,
    movie.year,
    duration,
    movie.director,
  ].filter(Boolean);

  return (
    <article
      className="movie-row grid gap-5 border-b border-[var(--line)] py-8 first:pt-2 last:border-b-0 sm:grid-cols-[8.5rem_1fr] sm:gap-7"
      style={{ animationDelay: `${Math.min(index, 8) * 0.05}s` }}
    >
      <div className="poster-frame relative mx-auto aspect-[2/3] w-[7.25rem] sm:mx-0 sm:w-full">
        {movie.posterUrl ? (
          <Image
            src={movie.posterUrl}
            alt={`Affiche — ${movie.title}`}
            fill
            className="object-cover"
            sizes="(max-width: 640px) 116px, 136px"
            unoptimized
          />
        ) : (
          <div className="flex h-full items-center justify-center px-2 text-center text-xs text-[var(--muted)]">
            Pas d&apos;affiche
          </div>
        )}
      </div>

      <div className="min-w-0">
        <header className="mb-5">
          <h2 className="font-[family-name:var(--font-display)] text-[1.55rem] leading-[1.15] tracking-tight text-[var(--foreground)] sm:text-[1.85rem]">
            {movie.title}
          </h2>
          {meta.length > 0 ? (
            <p className="mt-1.5 text-sm leading-snug text-[var(--muted)]">
              {meta.join(" · ")}
            </p>
          ) : null}
        </header>

        <div className="flex flex-col gap-6">
          {Array.from(byCinema.entries()).map(([cinemaKey, cinemaShowtimes]) => {
            const cinema = cinemaShowtimes[0].cinema;
            const byDay = new Map<string, typeof cinemaShowtimes>();
            for (const st of cinemaShowtimes) {
              const day = showtimeDay(st.startsAt);
              const list = byDay.get(day) ?? [];
              list.push(st);
              byDay.set(day, list);
            }

            return (
              <section key={cinemaKey}>
                <h3 className="mb-2.5 flex flex-wrap items-baseline gap-x-2 text-sm">
                  <span className="font-semibold text-[var(--fog)]">
                    {shortCinema(cinema.label)}
                  </span>
                  <span className="text-[var(--muted)]">{cinema.city}</span>
                </h3>
                <div className="flex flex-col gap-3.5">
                  {Array.from(byDay.entries()).map(([day, dayShowtimes]) => (
                    <div key={day}>
                      <p className="mb-2 text-[0.7rem] font-semibold uppercase tracking-[0.14em] text-[var(--muted)]">
                        {formatDayLong(day)}
                      </p>
                      <ul className="flex flex-wrap gap-2">
                        {dayShowtimes.map((st) => {
                          const inner = (
                            <>
                              <time
                                dateTime={st.startsAt}
                                className="text-sm font-semibold tabular-nums tracking-tight text-[var(--foreground)]"
                              >
                                {showtimeTime(st.startsAt)}
                              </time>
                              <RoomBadge label={st.roomLabel} />
                            </>
                          );

                          return (
                            <li key={st.id}>
                              {st.bookingUrl ? (
                                <a
                                  href={st.bookingUrl}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="showtime-chip"
                                  title="Ouvrir la billetterie"
                                >
                                  {inner}
                                </a>
                              ) : (
                                <span className="showtime-chip">{inner}</span>
                              )}
                            </li>
                          );
                        })}
                      </ul>
                    </div>
                  ))}
                </div>
              </section>
            );
          })}
        </div>
      </div>
    </article>
  );
}
