import { PrismaClient } from "~/generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import { env } from "~/env";

function applySslMode(url: string): string {
  const parsed = new URL(url);
  const sslmode = parsed.searchParams.get("sslmode");
  if (sslmode !== "verify-full" && sslmode !== "disable") {
    parsed.searchParams.set("sslmode", "verify-full");
  }
  return parsed.toString();
}

const createPrismaClient = () => {
  const adapter = new PrismaPg({
    connectionString: applySslMode(env.DATABASE_URL),
  });

  return new PrismaClient({
    adapter,
    log:
      env.NODE_ENV === "development"
        ? ["query", "error", "warn"]
        : ["error"],
  });
};

const globalForPrisma = globalThis as typeof globalThis & {
  prisma: ReturnType<typeof createPrismaClient> | undefined;
};

export const db = globalForPrisma.prisma ?? createPrismaClient();

if (env.NODE_ENV !== "production") globalForPrisma.prisma = db;
