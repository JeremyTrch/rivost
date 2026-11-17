import type { Movie } from "@/types/showtimes";

/**
 * Last-resort poster lookup by reading the public search pages of AlloCiné and TMDB.
 * Only called for films whose cinema feed has no working poster (a handful per refresh,
 * and the result is cached with the snapshot), so the load on those sites stays tiny.
 * Markup changes simply make a source return nothing; the app then draws its own poster.
 */

const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15";
const TIMEOUT_MS = 10_000;

interface Hit {
  title: string;
  originalTitle: string | null;
  director: string | null;
  date: Date | null;
  poster: string;
}

const MONTHS: Record<string, number> = {
  janvier: 0, fevrier: 1, mars: 2, avril: 3, mai: 4, juin: 5,
  juillet: 6, aout: 7, septembre: 8, octobre: 9, novembre: 10, decembre: 11,
};

export function fold(s: string | null | undefined): string {
  return (s ?? "")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ") // any punctuation (incl. – — · :) becomes a space
    .trim();
}

function decode(s: string): string {
  return s
    .replace(/&#0*39;|&apos;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ")
    .replace(/&#(\d+);/g, (_, n: string) => String.fromCodePoint(Number(n)))
    .replace(/&amp;/g, "&")
    .trim();
}

/** "28 octobre 2026" → Date */
function frenchDate(s: string | undefined): Date | null {
  const m = fold(s).match(/(\d{1,2}) ([a-z]+) (\d{4})/);
  if (!m || MONTHS[m[2]] === undefined) return null;
  return new Date(Date.UTC(Number(m[3]), MONTHS[m[2]], Number(m[1])));
}

async function page(url: URL): Promise<string | null> {
  try {
    const res = await fetch(url, {
      headers: {
        "User-Agent": UA,
        Accept: "text/html,application/xhtml+xml",
        "Accept-Language": "fr-FR,fr;q=0.9,en;q=0.6",
      },
      cache: "no-store",
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    return res.ok ? await res.text() : null;
  } catch {
    return null;
  }
}

async function searchAllocine(query: string): Promise<Hit[]> {
  const url = new URL("https://www.allocine.fr/rechercher/movie/");
  url.searchParams.set("q", query);
  const html = await page(url);
  if (!html) return [];

  const hits: Hit[] = [];
  for (const [, card] of html.matchAll(/<li class="mdl">([\s\S]*?)<\/li>/g)) {
    const src = card.match(/class="thumbnail-img"[^>]*data-src="([^"]+)"/)?.[1];
    const title = card.match(/meta-title-link"[^>]*>([^<]+)</)?.[1];
    if (!src || !title || src.includes("/empty/")) continue;
    hits.push({
      title: decode(title),
      originalTitle:
        card.match(/Titre original\s*<\/span>\s*<span[^>]*>([^<]+)</)?.[1]?.trim() ?? null,
      director: card.match(/meta-body-direction[\s\S]*?dark-grey-link">([^<]+)</)?.[1] ?? null,
      date: frenchDate(card.match(/class="date">([^<]+)</)?.[1]),
      // Drop the thumbnail transform ("/c_310_420/") to get the full-size poster.
      poster: src.replace(/\/c_\d+_\d+\//, "/"),
    });
  }
  return hits;
}

async function searchTmdb(query: string): Promise<Hit[]> {
  const url = new URL("https://www.themoviedb.org/search/movie");
  url.searchParams.set("query", query);
  url.searchParams.set("language", "fr-FR");
  const html = await page(url);
  if (!html) return [];

  const hits: Hit[] = [];
  for (const card of html.split('class="comp:media-card').slice(1, 11)) {
    const path = card.match(/\/t\/p\/w\d+(?:_and_h\d+)?(?:_face)?(\/[A-Za-z0-9]+\.(?:jpg|png|webp))/)?.[1];
    const title = card.match(/<h2[^>]*>\s*<span>([^<]+)<\/span>(?:<span class="font-light"> \(([^<]+)\)<\/span>)?/);
    if (!path || !title) continue;
    hits.push({
      title: decode(title[1]),
      originalTitle: title[2] ? decode(title[2]) : null,
      director: null,
      date: frenchDate(card.match(/release_date[^>]*>([^<]+)</)?.[1]),
      poster: `https://image.tmdb.org/t/p/w780${path}`,
    });
  }
  return hits;
}

/**
 * Picks the hits that are this film: the title must match; director, year and a release
 * close to today (it is on screen this week) break ties between homonyms.
 */
function rank(movie: Movie, hits: Hit[]): string[] {
  const titles = new Set([movie.title, movie.originalTitle].map(fold).filter(Boolean));
  const director = fold(movie.director);
  const now = Date.now();
  const year = 365 * 24 * 3600 * 1000;

  return hits
    .map((hit, index) => {
      if (!titles.has(fold(hit.title)) && !titles.has(fold(hit.originalTitle))) return null;
      let score = 0;
      if (director && hit.director && fold(hit.director) === director) score += 4;
      const released = hit.date?.getTime();
      if (released !== undefined) {
        if (movie.year && Math.abs(new Date(released).getUTCFullYear() - movie.year) <= 1) score += 2;
        if (released > now - 2 * year && released < now + year) score += 1;
      }
      return { poster: hit.poster, score, index };
    })
    .filter((x): x is { poster: string; score: number; index: number } => x !== null)
    .sort((a, b) => b.score - a.score || a.index - b.index)
    .map((x) => x.poster);
}

/** Candidate poster URLs for a film, best first (not yet checked for loading). */
export async function scrapePosters(movie: Movie): Promise<string[]> {
  // Long event titles ("La nuit de la glisse 2026 - THE CALL") often find nothing as a whole:
  // also try the part before the subtitle. Matching still requires the full title.
  const queries = [
    ...new Set(
      [movie.title, movie.originalTitle]
        .flatMap((t) => [t, t?.split(/\s+[-–—:]\s+/)[0]])
        .map((t) => t?.trim())
        .filter((q): q is string => Boolean(q)),
    ),
  ];
  const out: string[] = [];
  for (const search of [searchAllocine, searchTmdb]) {
    for (const query of queries) {
      const found = rank(movie, await search(query));
      out.push(...found.slice(0, 2));
      if (found.length) break;
    }
  }
  return [...new Set(out)];
}
