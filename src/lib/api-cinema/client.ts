import type {
  ApiCinemaList,
  ApiShowtimeList,
  CinemaShowtimeSearchBody,
  ShowtimeSearchBody,
} from "./types";

const API_BASE = "https://api.api-cinema.com";

export class ApiCinemaError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
  ) {
    super(message);
    this.name = "ApiCinemaError";
  }
}

function getApiKey(): string {
  const key = process.env.API_CINEMA_KEY;
  if (!key) {
    throw new ApiCinemaError(
      "API_CINEMA_KEY manquante. Ajoute-la dans .env.local (et sur Vercel).",
    );
  }
  return key;
}

async function apiFetch<T>(
  path: string,
  init?: RequestInit & { searchParams?: Record<string, string> },
): Promise<T> {
  const url = new URL(path, API_BASE);
  if (init?.searchParams) {
    for (const [k, v] of Object.entries(init.searchParams)) {
      url.searchParams.set(k, v);
    }
  }

  const { searchParams: _sp, ...rest } = init ?? {};
  const res = await fetch(url, {
    ...rest,
    headers: {
      Authorization: `Bearer ${getApiKey()}`,
      Accept: "application/json",
      "User-Agent": "rivost/0.1",
      ...(rest.body ? { "Content-Type": "application/json" } : {}),
      ...rest.headers,
    },
    // Cached by the 'use cache' wrapper in showtimes.ts — avoid double-caching fetch
    cache: "no-store",
  });

  if (!res.ok) {
    let detail = res.statusText;
    try {
      const body = (await res.json()) as { error?: string; message?: string };
      detail = body.error ?? body.message ?? detail;
    } catch {
      /* ignore */
    }
    throw new ApiCinemaError(`API Cinéma ${res.status}: ${detail}`, res.status);
  }

  return res.json() as Promise<T>;
}

export async function searchCinemas(query: string): Promise<ApiCinemaList> {
  return apiFetch<ApiCinemaList>("/v1/cinemas", {
    searchParams: {
      q: query,
      country: "FR",
      active: "true",
      limit: "50",
    },
  });
}

export async function searchShowtimes(
  body: ShowtimeSearchBody,
): Promise<ApiShowtimeList> {
  return apiFetch<ApiShowtimeList>("/v1/showtimes/search", {
    method: "POST",
    body: JSON.stringify(body),
  });
}

export async function searchCinemaShowtimes(
  cinemaIdOrSlug: string,
  body: CinemaShowtimeSearchBody,
): Promise<ApiShowtimeList> {
  return apiFetch<ApiShowtimeList>(
    `/v1/cinemas/${encodeURIComponent(cinemaIdOrSlug)}/showtimes/search`,
    {
      method: "POST",
      body: JSON.stringify(body),
    },
  );
}

/** Walk cursor pages until exhausted (quota-aware: prefer high limit). */
export async function fetchAllCinemaShowtimes(
  cinemaIdOrSlug: string,
  body: Omit<CinemaShowtimeSearchBody, "cursor" | "offset">,
): Promise<ApiShowtimeList["data"]> {
  const rows: ApiShowtimeList["data"] = [];
  let cursor: string | undefined;

  do {
    const page = await searchCinemaShowtimes(cinemaIdOrSlug, {
      ...body,
      limit: body.limit ?? 1000,
      ...(cursor ? { cursor } : {}),
    });
    rows.push(...page.data);
    cursor = page.meta.nextCursor ?? undefined;
  } while (cursor);

  return rows;
}
