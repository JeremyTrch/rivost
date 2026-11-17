import { connection } from "next/server";
import { parisToday } from "@/lib/dates";
import { loadShowtimesSnapshot } from "@/lib/showtimes";

/**
 * Public JSON feed used by the RiVOST iOS app.
 * Served from the same `use cache` snapshot as the web page, so mobile
 * clients never hit API Cinéma directly (key stays server-side, quota safe).
 */
export async function GET() {
  await connection();
  const snapshot = await loadShowtimesSnapshot();

  return Response.json(
    { ...snapshot, today: parisToday() },
    {
      status: snapshot.error ? 503 : 200,
      headers: {
        "Cache-Control": "public, s-maxage=900, stale-while-revalidate=3600",
      },
    },
  );
}
