import { fold, scrapePosters } from "@/lib/poster-scrape";
import type { Movie, Showtime } from "@/types/showtimes";

/**
 * Cinema feeds sometimes ship dead poster links (404/403 hotlink blocks) or none at all.
 * Before a snapshot is cached we check every candidate and keep only images that really load,
 * so the web page and the iOS app always get a working poster when one exists anywhere.
 *
 * Sources, best first:
 *   1. the film's own poster (upgraded to a sharper size when the CDN supports it)
 *   2. posters of the same film listed by another cinema (same TMDB id or same title)
 *   3. the public search pages of AlloCiné and TMDB (see poster-scrape.ts)
 *   4. the TMDB API, when TMDB_API_KEY is configured (by TMDB id, else by title search)
 */

const CHECK_TIMEOUT_MS = 6000;
const TMDB_TIMEOUT_MS = 8000;
const CONCURRENCY = 8;

const TMDB_IMAGE = "https://image.tmdb.org/t/p/w780";

/** Sharper variant of known thumbnail URLs (falls back to the original if it does not load). */
function upscaled(url: string): string | null {
  const hd = url
    .replace("/movie_poster/120/", "/movie_poster/800/")
    .replace("image.tmdb.org/t/p/w500/", "image.tmdb.org/t/p/w780/")
    .replace("image.tmdb.org/t/p/w342/", "image.tmdb.org/t/p/w780/");
  return hd === url ? null : hd;
}

const verified = new Map<string, Promise<boolean>>();

/** True when the URL answers 2xx with an image body. Memoised for one resolvePosters run. */
function loads(url: string): Promise<boolean> {
  let pending = verified.get(url);
  if (!pending) {
    pending = (async () => {
      try {
        const res = await fetch(url, {
          headers: {
            "User-Agent":
              "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            Accept: "image/avif,image/webp,image/*,*/*;q=0.8",
          },
          cache: "no-store",
          redirect: "follow",
          signal: AbortSignal.timeout(CHECK_TIMEOUT_MS),
        });
        const type = res.headers.get("content-type") ?? "";
        await res.body?.cancel().catch(() => {});
        return res.ok && type.startsWith("image/");
      } catch {
        return false;
      }
    })();
    verified.set(url, pending);
  }
  return pending;
}

function tmdbKey(): string | null {
  return process.env.TMDB_API_KEY?.trim() || null;
}

async function tmdb<T>(
  path: string,
  params: Record<string, string>,
): Promise<T | null> {
  const key = tmdbKey();
  if (!key) return null;
  const url = new URL(`https://api.themoviedb.org/3${path}`);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  // v4 read tokens are JWTs ("eyJ…"); v3 keys go in the query string.
  const bearer = key.startsWith("eyJ");
  if (!bearer) url.searchParams.set("api_key", key);
  try {
    const res = await fetch(url, {
      headers: {
        Accept: "application/json",
        ...(bearer ? { Authorization: `Bearer ${key}` } : {}),
      },
      cache: "no-store",
      signal: AbortSignal.timeout(TMDB_TIMEOUT_MS),
    });
    return res.ok ? ((await res.json()) as T) : null;
  } catch {
    return null;
  }
}

interface TmdbMovie {
  poster_path: string | null;
  title?: string;
  original_title?: string;
  release_date?: string;
}

interface TmdbImages {
  posters: Array<{ file_path: string; iso_639_1: string | null }>;
}

async function tmdbPosters(movie: Movie): Promise<string[]> {
  if (!tmdbKey()) return [];
  const out: string[] = [];

  if (movie.tmdbId) {
    const detail = await tmdb<TmdbMovie>(`/movie/${movie.tmdbId}`, {
      language: "fr-FR",
    });
    if (detail?.poster_path) out.push(TMDB_IMAGE + detail.poster_path);
    const images = await tmdb<TmdbImages>(`/movie/${movie.tmdbId}/images`, {
      include_image_language: "fr,en,null",
    });
    for (const p of images?.posters.slice(0, 3) ?? []) {
      out.push(TMDB_IMAGE + p.file_path);
    }
    if (out.length) return out;
  }

  const wanted = new Set(
    [movie.title, movie.originalTitle].map(fold).filter(Boolean),
  );
  const queries = [...new Set([movie.title, movie.originalTitle])].filter(
    (q): q is string => Boolean(q),
  );

  for (const query of queries) {
    const res = await tmdb<{ results: TmdbMovie[] }>("/search/movie", {
      query,
      language: "fr-FR",
      include_adult: "false",
    });
    const results = (res?.results ?? []).filter((r) => r.poster_path);
    const year = (r: TmdbMovie) => Number(r.release_date?.slice(0, 4)) || null;
    const titleMatch = (r: TmdbMovie) =>
      wanted.has(fold(r.title)) || wanted.has(fold(r.original_title));
    const yearMatch = (r: TmdbMovie) =>
      !movie.year || !year(r) || Math.abs(year(r)! - movie.year) <= 1;

    const best =
      results.find((r) => titleMatch(r) && yearMatch(r)) ??
      results.find(titleMatch);
    if (best?.poster_path) {
      out.push(TMDB_IMAGE + best.poster_path);
      return out;
    }
  }
  return out;
}

async function firstLoading(candidates: string[]): Promise<string | null> {
  for (const url of candidates) {
    if (await loads(url)) return url;
  }
  return null;
}

async function mapLimit<T, R>(
  items: T[],
  limit: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, async () => {
      while (next < items.length) {
        const i = next++;
        results[i] = await fn(items[i]);
      }
    }),
  );
  return results;
}

/** Replaces every movie's posterUrl with a URL verified to load (or null if none exists). */
export async function resolvePosters(showtimes: Showtime[]): Promise<void> {
  verified.clear(); // re-check on every refresh: a host that failed last time may be back
  const movies = new Map<string, Movie>();
  for (const st of showtimes) movies.set(st.movie.id, st.movie);

  // Same film listed under different ids by different cinemas: share their posters.
  const siblings = new Map<string, string[]>();
  const keysOf = (m: Movie) =>
    [
      m.tmdbId ? `tmdb:${m.tmdbId}` : null,
      fold(m.title) ? `t:${fold(m.title)}` : null,
      fold(m.originalTitle) ? `t:${fold(m.originalTitle)}` : null,
    ].filter((k): k is string => k !== null);
  for (const m of movies.values()) {
    if (!m.posterUrl) continue;
    for (const k of keysOf(m)) {
      siblings.set(k, [...(siblings.get(k) ?? []), m.posterUrl]);
    }
  }

  const own = (url: string | null) =>
    url ? [upscaled(url), url].filter((u): u is string => Boolean(u)) : [];

  const resolved = new Map<string, string | null>();
  await mapLimit([...movies.values()], CONCURRENCY, async (movie) => {
    const local = [
      ...own(movie.posterUrl),
      ...keysOf(movie).flatMap((k) => (siblings.get(k) ?? []).flatMap(own)),
    ];
    let url = await firstLoading([...new Set(local)]);
    if (!url) url = await firstLoading(await scrapePosters(movie));
    if (!url) url = await firstLoading(await tmdbPosters(movie));
    resolved.set(movie.id, url);
  });

  for (const st of showtimes) {
    st.movie = { ...st.movie, posterUrl: resolved.get(st.movie.id) ?? null };
  }
}
