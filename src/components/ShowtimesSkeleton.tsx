export function ShowtimesSkeleton() {
  return (
    <div className="animate-fade flex flex-col gap-6" aria-hidden>
      <div className="flex flex-col gap-3">
        <div className="h-3 w-16 rounded bg-white/10" />
        <div className="flex gap-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className="h-8 w-20 rounded-full bg-white/8" />
          ))}
        </div>
        <div className="flex gap-2">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="h-8 w-24 rounded-full bg-white/8" />
          ))}
        </div>
      </div>
      <div className="space-y-8 pt-4">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="grid gap-5 sm:grid-cols-[8.5rem_1fr]">
            <div className="aspect-[2/3] rounded bg-white/8" />
            <div className="space-y-3 pt-1">
              <div className="h-7 w-2/3 max-w-xs rounded bg-white/10" />
              <div className="h-4 w-1/2 max-w-[14rem] rounded bg-white/6" />
              <div className="mt-4 flex gap-2">
                <div className="h-8 w-16 rounded-md bg-white/8" />
                <div className="h-8 w-16 rounded-md bg-white/8" />
                <div className="h-8 w-16 rounded-md bg-white/8" />
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
