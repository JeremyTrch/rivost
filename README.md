# RiVOST

Agrégateur de **séances VOST** sur la Côte d’Azur — pour ne plus ouvrir quatre sites de cinéma.

**Cinémas couverts**

- Cinéum Cannes
- Pathé Lingostière Nice
- CGR Cagnes-sur-Mer
- Cinéplanet Antibes

Pour chaque séance : heure, cinéma, et type de salle / format (IMAX, Dolby, Lounge, Standard…).

## Stack

- [Next.js](https://nextjs.org) (App Router) + TypeScript + Tailwind
- [API Cinéma](https://api-cinema.com) (données séances)
- Déploiement [Vercel](https://vercel.com) + cron de refresh toutes les 6 h

## Démarrage local

```bash
npm install
cp .env.example .env.local
# renseigne API_CINEMA_KEY et CRON_SECRET
npm run dev
```

Ouvre [http://localhost:3000](http://localhost:3000).

## Variables d’environnement

| Variable | Où | Rôle |
|---|---|---|
| `API_CINEMA_KEY` | serveur uniquement | Clé Bearer API Cinéma (`ac_live_…`) |
| `CRON_SECRET` | serveur | Protège `GET /api/revalidate` |

Ne jamais committer `.env.local` ni exposer la clé côté client.

## Cache & quota

Le free plan API Cinéma limite à **250 requêtes / semaine**. RiVOST :

1. résout les 4 cinémas puis charge leurs séances VOST de la semaine ;
2. met le résultat en cache (~6 h) via Cache Components ;
3. le cron Vercel (`0 */6 * * *` → `/api/revalidate`) invalide le tag `showtimes`.

Les visiteurs lisent le cache : le quota reste largement sous la limite pour un usage personnel / public léger.

## Déploiement Vercel

1. Pousse le repo sur GitHub.
2. Importe le projet sur Vercel.
3. Ajoute `API_CINEMA_KEY` et `CRON_SECRET` (Production + Preview).
4. Deploy — le cron est défini dans [`vercel.json`](./vercel.json).

Sur Hobby, Vercel définit `CRON_SECRET` automatiquement pour les appels cron si tu l’as configuré ; sinon utilise la même valeur que dans le dashboard.

## Disclaimer

Horaires **non contractuels**. Vérifie toujours sur le site / la billetterie du cinéma. Données via API Cinéma ; métadonnées / affiches peuvent provenir de TMDB.

## Licence

MIT — voir [LICENSE](./LICENSE).
