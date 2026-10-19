import Image from "next/image";
import { RoomBadge } from "@/components/RoomBadge";
import { showtimeDay, showtimeTime } from "@/lib/showtimes-utils";
import type { MovieGroup } from "@/types/showtimes";

function formatDay(isoDay: string): string {
  const [y, m, d] = isoDay.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  return new Intl.DateTimeFormat("fr-FR", {
    weekday: "long",
    day: "numeric",
    month: "long",
    timeZone: "UTC",
  }).format(date);
}

function durationLabel(min: number | null): string | null {
  if (!min) return null;
  const h = Math.floor(min / 60);
  const m = min % 60;
  return h > 0 ? `${h}h${String(m).padStart(2, "0")}` : `${m} min`;
}

export function MovieCard({ group }: { group: MovieGroup }) {
  const { movie, showtimes } = group;
  const byCinema = new Map<string, typeof showtimes>();

  for (const st of showtimes) {
    const key = st.cinema.key;
    const list = byCinema.get(key) ?? [];
    list.push(st);
    byCinema.set(key, list);
  }

  const duration = durationLabel(movie.durationMin);

  return (
    <article className="grid gap-5 border-b border-white/10 py-8 first:pt-0 last:border-b-0 sm:grid-cols-[7.5rem_1fr] sm:gap-6">
      <div className="relative mx-auto aspect-[2/3] w-28 overflow-hidden rounded-md bg-white/5 shadow-lg shadow-black/40 sm:mx-0 sm:w-full">
        {movie.posterUrl ? (
          <Image
            src={movie.posterUrl}
            alt={`Affiche — ${movie.title}`}
            fill
            className="object-cover"
            sizes="112px"
            unoptimized
          />
        ) : (
          <div className="flex h-full items-center justify-center px-2 text-center text-xs text-[var(--muted)]">
            Pas d&apos;affiche
          </div>
        )}
      </div>

      <div className="min-w-0">
        <header className="mb-4">
          <h2 className="font-[family-name:var(--font-display)] text-2xl leading-tight tracking-tight text-[var(--foreground)] sm:text-[1.65rem]">
            {movie.title}
          </h2>
          <p className="mt-1 text-sm text-[var(--muted)]">
            {[movie.originalTitle && movie.originalTitle !== movie.title
              ? movie.originalTitle
              : null, movie.year, duration, movie.director]
              .filter(Boolean)
              .join(" · ")}
          </p>
        </header>

        <div className="flex flex-col gap-5">
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
                <h3 className="mb-2 text-sm font-semibold text-[var(--accent-soft)]">
                  {cinema.label}
                  <span className="ml-2 font-normal text-[var(--muted)]">
                    {cinema.city}
                  </span>
                </h3>
                <div className="flex flex-col gap-3">
                  {Array.from(byDay.entries()).map(([day, dayShowtimes]) => (
                    <div key={day}>
                      <p className="mb-1.5 text-xs uppercase tracking-wider text-[var(--muted)]">
                        {formatDay(day)}
                      </p>
                      <ul className="flex flex-wrap gap-2">
                        {dayShowtimes.map((st) => (
                          <li key={st.id}>
                            {st.bookingUrl ? (
                              <a
                                href={st.bookingUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="inline-flex items-center gap-2 rounded-lg border border-white/10 bg-[var(--surface)] px-2.5 py-1.5 transition hover:border-[var(--accent)]/40 hover:bg-white/[0.06]"
                              >
                                <time
                                  dateTime={st.startsAt}
                                  className="text-sm font-semibold tabular-nums"
                                >
                                  {showtimeTime(st.startsAt)}
                                </time>
                                <RoomBadge label={st.roomLabel} />
                              </a>
                            ) : (
                              <span className="inline-flex items-center gap-2 rounded-lg border border-white/10 bg-[var(--surface)] px-2.5 py-1.5">
                                <time
                                  dateTime={st.startsAt}
                                  className="text-sm font-semibold tabular-nums"
                                >
                                  {showtimeTime(st.startsAt)}
                                </time>
                                <RoomBadge label={st.roomLabel} />
                              </span>
                            )}
                          </li>
                        ))}
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
