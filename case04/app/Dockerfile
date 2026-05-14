# ─────────────────────────────
# Build stage
# ─────────────────────────────
FROM node:22-alpine AS builder

WORKDIR /app

# 依存だけ先にインストール(レイヤキャッシュ最適化)
COPY package.json package-lock.json ./
RUN npm ci

# Prisma スキーマをコピーしてクライアント生成
COPY prisma ./prisma
RUN npx prisma generate

# ソースコードをコピーしてビルド
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# ─────────────────────────────
# Production stage
# ─────────────────────────────
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# 本番依存だけインストール
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ビルド成果物を持ち込み
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma
COPY prisma ./prisma

# 非rootユーザーで実行(セキュリティ)
USER node

EXPOSE 3000

CMD ["node", "dist/server.js"]