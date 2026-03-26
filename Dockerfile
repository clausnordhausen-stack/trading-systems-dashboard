# ---------- Build stage ----------
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.* ./
RUN flutter pub get

COPY . .

RUN flutter config --enable-web
RUN flutter build web --release

# ---------- Runtime stage ----------
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 10000

CMD ["nginx", "-g", "daemon off;"]