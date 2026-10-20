import type { Metadata } from "next";
import { Fraunces, Manrope } from "next/font/google";
import "./globals.css";

const display = Fraunces({
  variable: "--font-display",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

const body = Manrope({
  variable: "--font-body",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: "RiVOST — séances VOST sur la Riviera",
  description:
    "Toutes les séances VOST de Cinéum Cannes, Pathé Lingostière, CGR Cagnes et Cinéplanet Antibes.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="fr"
      className={`${display.variable} ${body.variable} h-full antialiased`}
    >
      <body className="rivost-bg relative min-h-full flex flex-col">
        <div className="rivost-grain" aria-hidden />
        {children}
      </body>
    </html>
  );
}
