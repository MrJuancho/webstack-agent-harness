# Imagen de producción de la app. La etapa `build` compila TypeScript con
# todas las dependencias; `prod-deps` instala solo las de producción; la
# etapa final se queda con el JavaScript compilado y esas dependencias.
#
# `just image-check` (parte de `just gauntlet-full`) construye esta imagen
# y prueba que arranca, que se niega a arrancar sin configuración, que
# corre sin root, que migra y que se apaga de forma ordenada.

FROM node:22-alpine AS base
WORKDIR /app
# pnpm en la versión exacta del campo `packageManager` de package.json.
RUN corepack enable
COPY package.json pnpm-lock.yaml .npmrc ./

FROM base AS build
RUN pnpm install --frozen-lockfile
COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN pnpm run build

# Instalación limpia en vez de `pnpm prune --prod` sobre la de arriba: el
# prune deja carpetas vacías y binarios colgando de las devDependencies.
FROM base AS prod-deps
RUN pnpm install --prod --frozen-lockfile

FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY --from=base /app/package.json ./
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
# Los .sql no pasan por tsc: el migrador los lee de esta ruta en runtime.
COPY src/infra/db/migrations ./src/infra/db/migrations
# Usuario sin privilegios que ya trae la imagen oficial de Node.
USER node
EXPOSE 3000
# Forma exec (sin shell): node es PID 1 y recibe el SIGTERM de
# `docker stop` directamente -- condición para el apagado ordenado de
# src/http/server.ts.
CMD ["node", "dist/main.js"]
