import { connection } from "next/server";
import { ShowtimesBoard } from "@/components/ShowtimesBoard";
import { parisToday } from "@/lib/dates";
import { loadShowtimesSnapshot } from "@/lib/showtimes";

export async function ShowtimesSection() {
  await connection();
  const snapshot = await loadShowtimesSnapshot();
  const today = parisToday();
  return <ShowtimesBoard snapshot={snapshot} today={today} />;
}
