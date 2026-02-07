import NextAuth from "next-auth";
import GitHub from "next-auth/providers/github";
import Credentials from "next-auth/providers/credentials";
import { DrizzleAdapter } from "@auth/drizzle-adapter";
import { db } from "@/db";
import { users, accounts, sessions } from "@/db/schema";
import { eq } from "drizzle-orm";

const providers = [];

// Only add GitHub if credentials are configured
if (process.env.AUTH_GITHUB_ID && process.env.AUTH_GITHUB_SECRET) {
  providers.push(GitHub);
}

// Dev-only credentials provider for local testing
if (process.env.NODE_ENV === "development") {
  providers.push(
    Credentials({
      name: "Dev Login",
      credentials: {
        email: { label: "Email", type: "email", placeholder: "test@dispatch.local" },
      },
      async authorize(credentials) {
        const email = credentials?.email as string;
        if (!email) return null;

        // Find or create the user
        let [user] = await db.select().from(users).where(eq(users.email, email)).limit(1);
        if (!user) {
          const id = crypto.randomUUID();
          await db.insert(users).values({ id, email, name: email.split("@")[0] });
          [user] = await db.select().from(users).where(eq(users.id, id)).limit(1);
        }

        return user ? { id: user.id, name: user.name, email: user.email, image: user.image } : null;
      },
    })
  );
}

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: DrizzleAdapter(db, {
    usersTable: users,
    accountsTable: accounts,
    sessionsTable: sessions,
  }),
  providers,
  // Always use JWT — the adapter still persists users/accounts on OAuth sign-in,
  // but JWT avoids the incompatibility between Credentials provider and database sessions.
  session: { strategy: "jwt" },
  callbacks: {
    async signIn({ user, account }) {
      // Block sign-in if the user record wasn't created (shouldn't happen, but guard)
      if (!user?.id) return false;

      // For OAuth providers, check if this provider account is already linked to a different user.
      // The adapter handles linking automatically, but this guards against edge cases.
      if (account?.provider && account.provider !== "credentials") {
        const existing = await db
          .select()
          .from(accounts)
          .where(eq(accounts.providerAccountId, account.providerAccountId))
          .limit(1);
        if (existing.length > 0 && existing[0].userId !== user.id) {
          // This GitHub account is already linked to another user — reject
          return false;
        }
      }

      return true;
    },
    jwt({ token, user, account }) {
      // On initial sign-in, persist user id and provider info into the JWT
      if (user?.id) {
        token.sub = user.id;
        token.name = user.name;
        token.email = user.email;
        token.picture = user.image;
      }
      if (account) {
        token.provider = account.provider;
      }
      return token;
    },
    session({ session, token }) {
      if (token?.sub && session.user) {
        session.user.id = token.sub;
      }
      return session;
    },
  },
  pages: {
    signIn: "/login",
  },
});
