import { revalidatePath, revalidateTag } from "next/cache";
import { NextResponse } from "next/server";
import { SHOWTIMES_CACHE_TAG } from "@/lib/showtimes";

/**
 * Vercel Cron (and manual) cache refresh.
 * Protect with CRON_SECRET — Vercel sends Authorization: Bearer <CRON_SECRET>.
 */
export async function GET(request: Request) {
  const secret = process.env.CRON_SECRET;
  const auth = request.headers.get("authorization");

  if (!secret || auth !== `Bearer ${secret}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  revalidateTag(SHOWTIMES_CACHE_TAG, "max");
  revalidatePath("/");

  return NextResponse.json({
    revalidated: true,
    tag: SHOWTIMES_CACHE_TAG,
    at: new Date().toISOString(),
  });
}
